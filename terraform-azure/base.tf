terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.20.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "f7dc8823-4f06-4346-9de0-badbe6273a54"
}

resource "azurerm_resource_group" "resourcegroup" {
  name     = "mentoring_nshynkevich"
  location = "West Europe"

}

