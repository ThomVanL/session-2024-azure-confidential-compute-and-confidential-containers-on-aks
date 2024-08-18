variable "resource_group_name" {
  type    = string
  default = "tvl-win-cvm-tempdiskencr-rg"
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "password" {
  type      = string
  sensitive = true
}

variable "admin_username" {
  type    = string
  default = "adminuser"
}