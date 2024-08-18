targetScope = 'resourceGroup'

@description('Required. Specifies the Azure location where the key vault should be created.')
param location string = resourceGroup().location

@description('Required. Admin username of the Virtual Machine.')
param adminUsername string

@description('Required. Password or ssh key for the Virtual Machine.')
@secure()
param adminPasswordOrKey string

@description('Optional. Type of authentication to use on the Virtual Machine.')
@allowed([
  'password'
  'sshPublicKey'
])
param authenticationType string = 'password'

@description('Optional. Not before date in seconds since 1970-01-01T00:00:00Z.')
param keyNotBefore int = dateTimeToEpoch(utcNow())

@description('Optional. Expiry date in seconds since 1970-01-01T00:00:00Z.')
param keyExpiration int = dateTimeToEpoch(dateTimeAdd(utcNow(), 'P1Y'))

@description('Required. Name of the Virtual Machine.')
param vmName string

@description('Optional. Size of the VM.')
@allowed([
  'Standard_DC2ads_v5'
  'Standard_EC2ads_v5'
  // goes up to 96 core variants
  // Ensure you select SKUs with temp disks,
  // marked with the 'd' character
])
param vmSize string = 'Standard_DC2ads_v5'

@description('Optional. OS Image for the Virtual Machine')
@allowed([
  'Windows Server 2022 Gen 2'
  'Windows Server 2019 Gen 2'
  'Ubuntu 20.04 LTS Gen 2'
  'Ubuntu 22.04 LTS Gen 2'
])
param osImageName string = 'Ubuntu 20.04 LTS Gen 2'

@description('Optional. OS disk type of the Virtual Machine.')
@allowed([
  'Premium_LRS'
  'Standard_LRS'
  'StandardSSD_LRS'
])
param osDiskType string = 'Premium_LRS'

@description('Optional. Enable boot diagnostics setting of the Virtual Machine.')
@allowed([
  true
  false
])
param bootDiagnostics bool = false

@description('Optional. Specifies the EncryptionType of the managed disk. It is set to DiskWithVMGuestState for encryption of the managed disk along with VMGuestState blob, and VMGuestStateOnly for encryption of just the VMGuestState blob. NOTE: It can be set for only Confidential VMs.')
@allowed([
  'VMGuestStateOnly' // virtual machine guest state (VMGS) disk
  'DiskWithVMGuestState' // Full disk encryption
])
param securityType string = 'DiskWithVMGuestState'

@description('Required. Specifies the name of the key vault.')
param keyVaultName string

@description('Optional Specifies whether Azure Virtual Machines are permitted to retrieve certificates stored as secrets from the key vault.')
param enabledForDeployment bool = false

@description('Specifies whether Azure Disk Encryption is permitted to retrieve secrets from the vault and unwrap keys.')
param enabledForDiskEncryption bool = true

@description('Specifies whether Azure Resource Manager is permitted to retrieve secrets from the key vault.')
param enabledForTemplateDeployment bool = false

@description('Specifies the Azure Active Directory tenant ID that should be used for authenticating requests to the key vault. Get it by using Get-AzSubscription cmdlet.')
param tenantId string = subscription().tenantId

@description('Required. Specifies the name of the key that you want to create.')
param keyName string

@description('Optional. The type of the key. For valid values, see JsonWebKeyType. Must be backed by HSM, for secure key release.')
@allowed([
  'EC-HSM'
  'RSA-HSM'
])
param keyType string = 'RSA-HSM'

@description('Optional. Specifies whether the key should be exportable, "true" is required for secure key release.')
param keyExportable bool = true

@description('Optional. Determines whether or not the object is enabled, "true" is required for secure key release.')
param keyEnabled bool = true

@description('Optional. The elliptic curve name. For valid values, see JsonWebKeyCurveName.')
@allowed([
  'P-256'
  'P-256K'
  'P-384'
  'P-521'
])
param curveName string = 'P-256'

@description('Optional. The key size in bits. For example: 2048, 3072, or 4096 for RSA.')
param keySize int = -1

@description('Optional. Specifies the key operations that can be perform on the specific key. String array containing any of: "decrypt", "encrypt", "import", "release", "sign", "unwrapKey", "verify", "wrapKey"')
@allowed([
  'decrypt'
  'encrypt'
  'import'
  'sign'
  'unwrapKey'
  'verify'
  'wrapKey'
])
param keyOps array = [ 'encrypt', 'decrypt']

var releasePolicyContentType = 'application/json; charset=utf-8'
var releasePolicyData = loadFileAsBase64('../assets/cvm-release-policy.json')

var imageList = {
  'Windows Server 2022 Gen 2': {
    publisher: 'microsoftwindowsserver'
    offer: 'windowsserver'
    sku: '2022-datacenter-smalldisk-g2'
    version: 'latest'
  }
  'Windows Server 2019 Gen 2': {
    publisher: 'microsoftwindowsserver'
    offer: 'windowsserver'
    sku: '2019-datacenter-smalldisk-g2'
    version: 'latest'
  }
  'Ubuntu 20.04 LTS Gen 2': {
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-confidential-vm-focal' // 👈 Specific confidential VM image offer!
    sku: '20_04-lts-cvm' // 👈 Specific confidential VM image SKU!
    version: 'latest'
  }
  'Ubuntu 22.04 LTS Gen 2': {
    publisher: 'canonical'
    offer: '0001-com-ubuntu-confidential-vm-jammy' // 👈 Specific confidential VM image offer!
    sku: '22_04-lts-cvm' // 👈 Specific confidential VM image SKU!
    version: 'latest'
  }
}

var virtualNetworkName = '${vmName}-vnet'
var subnetName = '${vmName}-vnet-sn'
var subnetResourceId = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
var addressPrefix = '10.0.0.0/16'
var subnetPrefix = '10.0.0.0/24'

var isWindows = contains(osImageName, 'Windows')

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2023-06-01' = {
  name: '${vmName}-ip'
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-06-01' = {
  name: '${vmName}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: (isWindows ? 'RDP' : 'SSH')
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: (isWindows ? '3389' : '22')
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-06-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2023-06-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetResourceId
          }
          publicIPAddress: {
            id: publicIPAddress.id
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource confidentialVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: bootDiagnostics
      }
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
          securityProfile: {
            securityEncryptionType: securityType
          }
        }
      }
      imageReference: imageList[osImageName]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPasswordOrKey
      linuxConfiguration: ((authenticationType == 'password') ? null : {
        disablePasswordAuthentication: 'true'
        ssh: {
          publicKeys: [
            {
              keyData: adminPasswordOrKey
              path: '/home/${adminUsername}/.ssh/authorized_keys'
            }
          ]
        }
      })
      windowsConfiguration: (!isWindows ? null : {
        enableAutomaticUpdates: 'true'
        provisionVmAgent: 'true'
      })
    }
    securityProfile: {
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
      securityType: 'ConfidentialVM'
    }
  }
}

resource kv 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForDeployment: enabledForDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    enabledForTemplateDeployment: enabledForTemplateDeployment
    tenantId: tenantId
    enableRbacAuthorization: true
    sku: {
      name: 'premium'
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource key 'Microsoft.KeyVault/vaults/keys@2023-07-01' = {
  parent: kv
  name: keyName
  properties: {
    kty: keyType
    attributes: {
      exportable: keyExportable
      enabled: keyEnabled
      nbf: keyNotBefore == -1 ? null : keyNotBefore
      exp: keyExpiration == -1 ? null : keyExpiration
    }
    curveName: curveName
    keySize: keySize == -1 ? null : keySize
    keyOps: keyOps
    release_policy: {
      contentType: releasePolicyContentType
      data: releasePolicyData
    }
  }
}

var roleDefKeyVaultCryptoServiceReleaseUser = resourceId('Microsoft.Authorization/roleAssignments', '08bbd89e-9f13-488c-ac41-acfcb10c90ab')
resource releaseKeyRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(key.id, confidentialVm.id, roleDefKeyVaultCryptoServiceReleaseUser)
  scope: key
  properties: {
    principalType: 'ServicePrincipal'
    principalId: confidentialVm.identity.principalId
    // Key Vault Crypto Service Release User
    // Release keys. Only works for key vaults that use the 'Azure role-based access control' permission model.
    roleDefinitionId:roleDefKeyVaultCryptoServiceReleaseUser
  }
}

var extensionName =  isWindows ? 'AzureDiskEncryption' : 'AzureDiskEncryptionForLinux'
var extensionVersion = isWindows ? '2.2' :'1.0'
var extensionPublisher = 'Microsoft.Azure.Security'

resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: confidentialVm
  name: extensionName
  location: location
  properties: {
    publisher: extensionPublisher
    type: extensionName
    typeHandlerVersion: extensionVersion
    autoUpgradeMinorVersion: true
    settings: {
      EncryptionOperation: 'EnableEncryption'
      KeyVaultURL: kv.properties.vaultUri
      KeyVaultResourceId: kv.id
      KeyEncryptionAlgorithm: 'RSA-OAEP'
      VolumeType: 'Data'
      KeyEncryptionKeyURL: key.properties.keyUriWithVersion
      KekVaultResourceId: split(key.id, '/keys')[0]
    }
  }
  dependsOn: [
    releaseKeyRoleAssignment
  ]
}
