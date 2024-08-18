

locals {
  vm_name              = random_string.random.result
  virtual_network_name = "${local.vm_name}-vnet"
  subnet_name          = "${local.vm_name}-vnet-sn"
  pip_name             = "${local.vm_name}-ip"
  nsg_name             = "${local.vm_name}-nsg"
  nic_name             = "${local.vm_name}-nic"
  kv_name              = "${local.vm_name}-kv"
  addressPrefix        = ["10.0.0.0/16"]
  subnetPrefix         = ["10.0.0.0/24"]
  is_password          = lower(var.auth_type) == "password"
}

resource "random_string" "random" {
  length  = 7
  special = false
  lower   = true
}

resource "azurerm_resource_group" "tempdiskblog" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "tempdiskblog" {
  resource_group_name = azurerm_resource_group.tempdiskblog.name
  location            = azurerm_resource_group.tempdiskblog.location

  name          = local.virtual_network_name
  address_space = local.addressPrefix
}

resource "azurerm_subnet" "cvm" {
  resource_group_name = azurerm_resource_group.tempdiskblog.name

  name                 = local.subnet_name
  virtual_network_name = azurerm_virtual_network.tempdiskblog.name
  address_prefixes     = local.subnetPrefix

}

resource "azurerm_public_ip" "tempdiskblog" {
  resource_group_name = azurerm_resource_group.tempdiskblog.name
  location            = azurerm_resource_group.tempdiskblog.location

  name              = local.pip_name
  allocation_method = "Dynamic"
  sku               = "Basic"
}

resource "azurerm_network_security_group" "sn_cvm" {
  resource_group_name = azurerm_resource_group.tempdiskblog.name
  location            = azurerm_resource_group.tempdiskblog.location

  name = local.nsg_name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "sn_cvm" {
  subnet_id                 = azurerm_subnet.cvm.id
  network_security_group_id = azurerm_network_security_group.sn_cvm.id
}

resource "azurerm_network_interface" "cvm" {
  resource_group_name = azurerm_resource_group.tempdiskblog.name
  location            = azurerm_resource_group.tempdiskblog.location

  name = local.nic_name
  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.cvm.id
    public_ip_address_id          = azurerm_public_ip.tempdiskblog.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "cvm" {
  resource_group_name = azurerm_resource_group.tempdiskblog.name
  location            = azurerm_resource_group.tempdiskblog.location

  name = local.vm_name
  size = "Standard_DC2ads_v5"
  identity {
    type = "SystemAssigned"
  }

  admin_username                  = var.admin_username
  admin_password                  = local.is_password ? var.password_or_key_path : null
  disable_password_authentication = local.is_password ? false : true
  network_interface_ids           = [azurerm_network_interface.cvm.id]

  dynamic "admin_ssh_key" {
    for_each = local.is_password == false ? ["enabled"] : []
    content {
      username   = var.admin_username
      public_key = file(var.password_or_key_path)
    }
  }

  os_disk {
    caching                  = "ReadWrite"
    storage_account_type     = "Standard_LRS"
    security_encryption_type = "DiskWithVMGuestState" # Confidential Disk Encryption
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-confidential-vm-jammy"
    sku       = "22_04-lts-cvm"
    version   = "latest"
  }
  secure_boot_enabled = true
  vtpm_enabled        = true
}

resource "azurerm_key_vault" "cvm" {
  resource_group_name = azurerm_resource_group.tempdiskblog.name
  location            = azurerm_resource_group.tempdiskblog.location

  name      = local.kv_name
  sku_name  = "premium"
  tenant_id = data.azurerm_client_config.current.tenant_id

  enable_rbac_authorization   = true
  enabled_for_disk_encryption = true
  purge_protection_enabled    = false # Change this if you need it
  soft_delete_retention_days  = 7
}

data "azurerm_client_config" "current" {}

resource "azurerm_role_assignment" "current_user" {
  principal_id         = data.azurerm_client_config.current.object_id
  scope                = azurerm_key_vault.cvm.id
  role_definition_name = "Key Vault Crypto Officer"
}

resource "azurerm_role_assignment" "cvm_key_release" {
  principal_id         = azurerm_linux_virtual_machine.cvm.identity[0].principal_id
  scope                = azapi_resource.cvm_key.id
  role_definition_name = "Key Vault Crypto Service Release User"
}

data "local_file" "cvm_release_policy" {
  filename = "${path.root}/../../assets/cvm-release-policy.json"
}

resource "azapi_resource" "cvm_key" {
  type                   = "Microsoft.KeyVault/vaults/keys@2022-07-01"
  name                   = local.vm_name
  parent_id              = azurerm_key_vault.cvm.id
  response_export_values = ["properties.keyUriWithVersion"]
  body = jsonencode({
    properties = {
      attributes = {
        enabled    = true
        exportable = true
      }
      keyOps = [
        "encrypt",
        "decrypt"
      ]
      keySize = 2048
      kty     = "RSA-HSM"
      release_policy = {
        contentType = "application/json; charset=utf-8"
        # The Auzre Key Vault backend stores a minified version of your policy
        # it will also remove the padding. To prevent Terraform from wanting to update
        # the release_policy on subsequent runs, trim the equals characters.
        data = trim(data.local_file.cvm_release_policy.content_base64, "=")
      }
    }
  })
}

resource "azurerm_virtual_machine_extension" "cvm_ade" {
  name                       = "AzureDiskEncryptionForLinux"
  virtual_machine_id         = azurerm_linux_virtual_machine.cvm.id
  type_handler_version       = "1.1"
  publisher                  = "Microsoft.Azure.Security"
  type                       = "AzureDiskEncryptionForLinux"
  auto_upgrade_minor_version = true
  settings                   = <<EOF
{
  "EncryptionOperation": "EnableEncryption",
  "KeyVaultURL": "${azurerm_key_vault.cvm.vault_uri}",
  "KeyVaultResourceId": "${azurerm_key_vault.cvm.id}",
  "KeyEncryptionAlgorithm": "RSA-OAEP",
  "VolumeType": "Data",
  "KeyEncryptionKeyURL": "${jsondecode(azapi_resource.cvm_key.output).properties.keyUriWithVersion}",
  "KekVaultResourceId": "${azapi_resource.cvm_key.parent_id}"
}
  EOF
  depends_on = [ azurerm_role_assignment.cvm_key_release ]
}