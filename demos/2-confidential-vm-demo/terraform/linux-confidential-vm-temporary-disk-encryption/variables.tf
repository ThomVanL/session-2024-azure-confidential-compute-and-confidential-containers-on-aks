variable "resource_group_name" {
  type    = string
  default = "tvl-linux-cvm-tempdiskencr-rg"
}

variable "location" {
  type    = string
  default = "westeurope"
}

variable "auth_type" {
  type    = string
  default = "password"
  validation {
    condition     = contains(["password", "key"], lower(var.auth_type))
    error_message = "auth_type must have value 'password' or 'key'."
  }
}

variable "password_or_key_path" {
  type      = string
  sensitive = true
}

variable "admin_username" {
  type    = string
  default = "adminuser"
}