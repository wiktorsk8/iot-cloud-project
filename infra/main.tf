resource "azurerm_resource_group" "rg" {
  name     = var.rg_name
  location = var.location
}

# =====================================================================
#  Azure Container Registry (prywatny rejestr obrazów)
#  admin_enabled = false -> NIE używamy loginu/hasła, tylko Managed Identity
#  Push obrazu robisz przez `az acr login` (autoryzacja AD)
# =====================================================================
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  # admin_enabled = true tylko po to, by GitHub Actions mógł PUSHOWAĆ obraz.
  # Pull do App Service nadal idzie wyłącznie przez Managed Identity (patrz niżej).
  # Service Principal/OIDC byłyby czystsze, ale tenant uczelni blokuje rejestrację aplikacji w AD.
  admin_enabled = true
}

# =====================================================================
#  Hasło do SQL — generowane przez Terraform (zero hardcoded credentials)
#  override_special pomija znaki, które psują connection string (; = ' " {})
# =====================================================================
resource "random_password" "sql" {
  length           = 24
  special          = true
  override_special = "!#$%*-_+"
}

# =====================================================================
#  Azure SQL: serwer + baza (warstwa Basic = najtańsza) + firewall
# =====================================================================
resource "azurerm_mssql_server" "sql" {
  name                         = var.sql_server_name
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_login
  administrator_login_password = random_password.sql.result
}

resource "azurerm_mssql_database" "db" {
  name      = var.sql_db_name
  server_id = azurerm_mssql_server.sql.id
  sku_name  = "Basic"
}

# Reguła 0.0.0.0 -> 0.0.0.0 to specjalne "Allow Azure services" (App Service dostanie się do SQL)
resource "azurerm_mssql_firewall_rule" "azure_services" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Opcjonalnie: Twój IP, żeby testować /db z lokalnej maszyny
# resource "azurerm_mssql_firewall_rule" "my_ip" {
#   count            = var.my_ip == "" ? 0 : 1
#   name             = "AllowMyIP"
#   server_id        = azurerm_mssql_server.sql.id
#   start_ip_address = var.my_ip
#   end_ip_address   = var.my_ip
# }

# =====================================================================
#  App Service Plan (Linux, F1 Free)
# =====================================================================
resource "azurerm_service_plan" "plan" {
  name                = var.plan_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Linux"
  sku_name            = "F1"
}

# =====================================================================
#  Linux Web App (kontener z ACR)
#  - System-assigned Managed Identity (do pobierania obrazu z ACR)
#  - connection string do SQL wstrzyknięty jako app_setting (czytany z env)
# =====================================================================
resource "azurerm_linux_web_app" "app" {
  name                = var.app_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_service_plan.plan.location
  service_plan_id     = azurerm_service_plan.plan.id

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = false # F1 Free nie wspiera Always On

    application_stack {
      docker_image_name   = "${var.image_name}:${var.image_tag}"
      docker_registry_url = "https://${azurerm_container_registry.acr.login_server}"
    }
    container_registry_use_managed_identity = true
  }

  app_settings = {
    "WEBSITES_PORT"         = var.container_port
    "PORT"                  = var.container_port
    "DOCKER_ENABLE_CI"      = "true"
    "SQL_CONNECTION_STRING" = "Server=tcp:${azurerm_mssql_server.sql.fully_qualified_domain_name},1433;Database=${var.sql_db_name};User ID=${var.sql_admin_login};Password=${random_password.sql.result};Encrypt=true;TrustServerCertificate=False;Connection Timeout=30;"
  }
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.app.identity[0].principal_id
}

# =====================================================================
#  Continuous Deployment: webhook w ACR -> App Service
#  Po każdym pushu obrazu z tagiem `latest` ACR "puka" do endpointu CD
#  App Service (/docker/hook), a ta automatycznie pobiera nowy obraz
#  (przez Managed Identity). Realizuje wymóg 4.0 (auto-update < 2 min).
#
#  service_uri zawiera publishing credentials Web Appki (site_credential) —
#  to uwierzytelnienie samego webhooka wobec App Service, NIE creds do ACR.
# =====================================================================
resource "azurerm_container_registry_webhook" "cd" {
  name                = "appservicecd"
  registry_name       = azurerm_container_registry.acr.name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  service_uri = "https://${azurerm_linux_web_app.app.site_credential[0].name}:${azurerm_linux_web_app.app.site_credential[0].password}@${azurerm_linux_web_app.app.name}.scm.azurewebsites.net/docker/hook"
  status      = "enabled"
  scope       = "${var.image_name}:${var.image_tag}" # iot-app:latest
  actions     = ["push"]
}
