variable "subscription_id" {
  type = string
}

variable "client_id" {
  type = string
}

variable "client_secret" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "resource_group_location" {
  type    = string
  default = "eastus"
}

variable "resource_group_name_prefix" {
  type    = string
  default = "student-rg"
}

variable "username" {
  type    = string
  default = "azureuser"
}

variable "vm_admin_password" {
  type = string
}
