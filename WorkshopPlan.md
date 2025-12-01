

I would like to create workshop materials where I will teach and show how Azure Infrastructure services students uses. Detailed information is following;

# **Theme and Goals**

## Theme
  - Resilient Azure IaaS architecture with availability zones and cross region replication for DR.

## Goal:
  1. Understand how availability zones and Azure infrastructure services like VM, VNet, Managed Disks, Storage should be used for resilient systems.
  2. Understand how monitoring service should be used and configured to have operational excellence.
  3. Understand how BCDR service should be used to have business continuity.

# **What Azure services are used**
  - Main services which students need to understand:
    1. Azure Virtual Machines
    2. Virtual Networks
    3. Network Security Group
    4. Standard Load Balancer
    5. Public IPs
    6. Managed Disks
    7. Blob Storage
    8. Azure Monitor and Azure Monitor Agent
    9. Log Analytics
    10. Azure Backup
    11. Azure Site Recovery
    12. Azure Bastion

  - Surrounding services which students do not need to understand at this workshop but this sample system should have from the perspective of Azure Well-architected Framework:
    1. Microsoft Entra ID and authentication mechanism with it
    2. Microsoft Defender for Cloud

  - Not used services but students should understand:
    1. Application Gateway and Web Application Firewall. It is better choise than Standard Load Balancer for Web/App tier but workshop time is so limited that Standard load balancer is used for it. I would like to add some explanation for this portion.
    2. Azure Files. This workshop use Blob Storage for static asset data store however some users need to use Azure Files instead of Blob Storage due to some background or restrictions. I would like to explain use cases and pros & cons.
    3. Azure PaaS like App Service, DBaaS. These PaaS will be used in next workshop.

# **Sample application information**
  1. Sample application theme: A blog site with multi users
  2. Architecture and technical requrirements:
  - Traditional 3 tiered web application
    - Frontend: React with tailwindcss
    - Web tier: NGINX
    - App tier: Express
    - DB tier: MongoDB
    - Language: TypeScript
    - Coding standard: [Google TypeScript Stuyle Guide](https://google.github.io/styleguide/tsguide.html)
    - OS: Ubuntu 24.04 LTS

# **Student target**

  - Not beginner. Experienced 3 to 5 years for Enterprise infrastructure design, operation.
  - Some experienced for AWS as the certification level with AWS Solution Architect Associate or more.
  - Less experience with Azure than AWS. Certification level is AZ-900 to AZ-104. Not AZ-305 level.
  - Some experience with JavaScript/TypeScript, React, Express and MongoDB.

# **Prerequisition for students**
  Bring following items and materials for this workshop.
  - An Azure subscription which you can use as sandbox environment.
  - PC connected to Internet. I strongly recommend it can connect to Internet **without Proxy**.
  - VSCode
  - Azure CLI 
  - GitHub account. Students should not use this repository directly but folk it to each student's repository.

# **Workshop information and requrirement**

## **Workshop Style**

I would like to have this workshop in off-line style as possible because teacher and assistants can support students easily.

## **Necessary time**

Around 4 hours. Assuming this workshop is held afternoon.

## **Assuming attendees number**

I'm assuming 20 students. The maximum number would be 30.

## **Workshop steps**

  1. Before this workshop, students attend the cource for AWS users to understand Azure in class-room style.
  2. Start this workshop:

    1. Deploy each Azure services
      - Main method: With using Azure Portal.
      - Alternative method 1: With using Azure CLI.
      - Alternative method 2: 