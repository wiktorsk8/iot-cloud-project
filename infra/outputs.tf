output "app_url" {
  description = "Publiczny adres aplikacji"
  value       = "https://${azurerm_linux_web_app.app.default_hostname}"
}

output "acr_login_server" {
  description = "Adres rejestru ACR (do docker tag/push)"
  value       = azurerm_container_registry.acr.login_server
}

output "sql_fqdn" {
  description = "Adres serwera Azure SQL"
  value       = azurerm_mssql_server.sql.fully_qualified_domain_name
}
