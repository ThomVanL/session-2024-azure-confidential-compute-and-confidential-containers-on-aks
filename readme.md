# Session - Confidential Compute and Confidential Containers on AKS

## Session description

In today’s digital world, the convenience of cloud computing often raises concerns about data sovereignty and security. Azure Confidential Computing can provide the confidentiality guarantees of a private data center while harnessing the power and scalability of the cloud by providing hardware-based trusted execution environments (TEEs) that ensure data remains secure even while in use!

This session will briefly explore Microsoft’s confidential computing offerings, but we will focus on the Confidential Containers project (CoCo) and its integration with Azure Kubernetes Service (AKS). This Cloud Native Computing Foundation project simplifies deploying confidential computing workloads to Kubernetes, ensuring that only the Kubernetes CoCo pod and confidential hardware are trusted.

We will look at how to leverage our existing Kubernetes knowledge and tools with CoCo. In doing so, we can quickly and effectively lift-and-shift our applications without needing deep expertise in confidential computing technologies. We'll also touch upon integrating these advancements into Confidential AI to further enhance the security and privacy of AI workloads.

## Available demos

- [Unencrypted memory](demos/1-unencrypted-memory/readme.md)
- [Bicep and Terraform: Deploy Azure Confidential Virtual Machine with ADM SEV-SNP](demos/2-confidential-vm-demo/readme.md)
- [Running a Kafka Workload with CoCo on Azure Kubernetes Service](demos/3-coco-kafka-workload/readme.md)

## Available media

- [▶️ Azure Back to School 2024 - YouTube recording](https://www.youtube.com/watch?v=qh-lSqifhj8)
- [📋 PDF slide deck](confidential-compute-and-confidential-containers-on-aks.pdf)