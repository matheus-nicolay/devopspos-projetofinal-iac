terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-rg"
    storage_account_name = "terraformsgmatheus"
    container_name       = "terraformcontainer"
    key                  = "prod.terraform.tfstate"
  }
}