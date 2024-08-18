terraform {
  required_providers {
    azapi = {
      version = "~> 1.11.0"
      source  = "Azure/azapi"
    }
    azurerm = {
      version = "~> 3.85.0"
      source  = "hashicorp/azurerm"
    }
    local = {
      version = "~> 2.4.0"
      source  = "hashicorp/local"
    }
    random = {
      version = "~> 3.6.0"
      source  = "hashicorp/random"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

provider "azapi" {
  skip_provider_registration = true
}
