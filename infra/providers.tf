terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # KROK 4 — migracja state do Azure Storage (remote backend).
  # Najpierw zbootstrapuj konto storage w osobnym RG (rg-tfstate),
  # potem odkomentuj poniższe i uruchom: terraform init -migrate-state
  #
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstate21886"
    container_name       = "tfstate"
    key                  = "iot-projekt.tfstate"
  }
}

provider "azurerm" {
  features {}
}
