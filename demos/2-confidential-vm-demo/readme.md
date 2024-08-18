# Azure Confidential Virtual Machine with AMD SEV-SNP

This is another super simple demo where we deploy a confidential VM in Azure. In this setup, the VM comes with both confidential OS disk and temporary disk encryption. The samples are based on my blog post on [Confidential Temp Disk Encryption](https://thomasvanlaere.com/posts/2023/12/azure-confidential-computing-confidential-temp-disk-encryption/).

## Demo files

- **Bicep:** [Bicep Deployment Scripts](./bicep/)
- **Terraform:**
  - [Confidential Windows VM](./terraform/windows-confidential-vm-temporary-disk-encryption/)
  - [Confidential Linux VM](./terraform/linux-confidential-vm-temporary-disk-encryption/)

## What This Demo Does

The infrastructure-as-code executes the following actions:

- **Deploy the Confidential Virtual Machine (CVM):**
  - Enable confidential OS disk encryption using a platform-managed key.
  - Enable Managed Identity.

- **Deploy an Azure Key Vault Premium:**
  - Create a role assignment that allows the CVM to perform release operations against key objects.
  - Grant permission for its objects to be used in Azure Disk Encryption.

- **Create an HSM-backed RSA Key:**
  - Mark the key as exportable.
  - Attach an SKR policy.

## SKR Policy Validation

The SKR policy enforces these criteria:

- Verify that the attestation token was signed by the sharedweu Azure Attestation instance.
- Confirm that the CVM is of type **sevsnpvm** (for AMD SEV-SNP) or **tdxvm** (for Intel TDX).

## Additional Considerations

- **ADE Extension:**  
  Deploying the Azure Disk Encryption (ADE) extension is necessary. It requires specific parameters to integrate with the Key Vault instance.

- **VM Extension Nuances:**  
  While deploying a VM extension is straightforward, keep an eye out for configuration differences between Linux and Windows. One notable difference is the version of the disk encryption extension used. An incorrect version can complicate the deployment process.

- **Terraform vs. Bicep:**  
  Deploying a confidential VM via Terraform is possible, but it differs slightly from using Bicep. With Bicep, you can control the `securityType` attribute—set it to `ConfidentialVM`—and optionally configure secure boot and activate the vTPM, which is highly recommended.