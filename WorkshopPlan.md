

I would like to create workshop materials where I will teach and show how Azure Infrastructure services students uses. Detailed information is following;

# **Workshop theme and goals**

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
    - Authentication: OAuth2.0 with Microsoft Entra ID tenant

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

2 days (Full workshop version):
- **Day 1**: 4 hours - Infrastructure deployment, HA configuration, and monitoring (Steps 1-6)
- **Day 2**: 4 hours - Business Continuity and Disaster Recovery (Steps 7-13)

Note: A condensed 4-hour version will be created later by automating/skipping certain portions.

## **Assuming attendees number**

I'm assuming 20 students. The maximum number would be 30.

## **Workshop steps**

  - Before this workshop, students attend the cource for AWS users to understand Azure in class-room style.
  - Start this workshop:

  ### **Day 1: Infrastructure Deployment, HA Configuration, and Monitoring (4 hours)**
  
    **Focus**: Deploy Azure infrastructure services, configure high availability, and set up monitoring
    
    **Steps**:
    1. Deploy each Azure services
      - Main method: With using Bicep ("Deploy to Azure" button) for consistent and fast deployment
      - Alternative method 1: With using Azure Portal for learning and understanding each service
      - Alternative method 2: With using Azure CLI for automation-oriented students
      - This repository need to have Bicep file for the main deployment method
    2. Configure DB servers with HA. Some automatic deployment like GitHub Actions is preferred because configuration is not main portion at this workshop.
    3. Configure App servers and deploy the codes to them. Some automatic deployment like GitHub Actions is preferred because configuration is not main portion at this workshop.
    4. Configure Web servers. Some automatic deployment like GitHub Actions is preferred because configuration is not main portion at this workshop.
    5. Check how this sample system works in normal situation where is no incident or no any failure.
    6. Check metrics and logs with using Log Analytics which can utilize IT system operation like alerting or analysis.
    
    **Day 1 Goals**: 
    - Understand Azure IaaS architecture with Availability Zones
    - Experience HA configuration across multiple tiers
    - Learn how to use Azure Monitor and Log Analytics for operational excellence

  ### **Day 2: Business Continuity and Disaster Recovery (4 hours)**
  
    **Focus**: Implement and test backup/restore strategies and disaster recovery procedures
    
    **Prerequisites**: Day 1 environment should be running and operational
    
    **Steps**:
    7. Add some data and get on-demand backup with Azure Backup.
    8. Restore the data with Azure Backup.
    9. Stop a Web server and check the system is still working (HA validation).
    10. Restart a Web server and check the system status.
    11. (Core) Stop and restart an App server with checking the system status.
    12. (Core) Stop and restart a DB server with checking the system status.
    13. (Core) Try to execute DR with using Azure Site Recovery and check the system starts to work in another region.
    
    **Day 2 Goals**:
    - Understand Azure Backup and restore procedures
    - Experience real-world failure scenarios and HA behavior
    - Learn disaster recovery concepts with Azure Site Recovery


# How do I want to proceed this workshop preparation.

## Overview of steps of preparation.

1. Create detailed workshop materials and infrastructure code
2. Prepare Bicep templates for automated deployment
3. Create GitHub Actions workflows for application deployment
4. Develop step-by-step instructions for each workshop step
5. Create troubleshooting guide and FAQ
6. Test the full workshop flow
7. After completing 2-day version, create condensed 4-hour version

## Additional items to be prepared

### **Time Table (Detailed)**

#### Day 1 Timeline
- 0:00-0:15: Introduction, objectives, environment verification
- 0:15-0:45: Deploy infrastructure using Bicep ("Deploy to Azure" button)
- 0:45-1:15: Architecture explanation while deployment is in progress
- 1:15-1:30: Break
- 1:30-2:15: Configure and deploy DB, App, and Web tiers (Steps 2-4)
- 2:15-2:45: Test and validate application functionality (Step 5)
- 2:45-3:00: Break
- 3:00-3:45: Configure and explore Azure Monitor and Log Analytics (Step 6)
- 3:45-4:00: Day 1 summary, Q&A, preview of Day 2

#### Day 2 Timeline
- 0:00-0:15: Day 1 recap, Day 2 objectives
- 0:15-1:00: Azure Backup configuration and on-demand backup (Step 7)
- 1:00-1:30: Restore testing (Step 8)
- 1:30-1:45: Break
- 1:45-2:30: HA testing - Web and App tier failures (Steps 9-11)
- 2:30-2:45: Break
- 2:45-3:30: DB tier failure testing and ASR preparation (Step 12)
- 3:30-3:50: DR execution with Azure Site Recovery (Step 13)
- 3:50-4:00: Workshop summary, resource cleanup instructions, Q&A

### **Cost Estimation**
- Estimate per student for 2-day workshop
- Include breakdown by service (VMs, Storage, Load Balancer, etc.)
- Provide resource cleanup checklist to prevent ongoing charges

### **Prerequisites Checklist**

#### For Students (Pre-workshop verification):
- [ ] Azure subscription with sufficient permissions (Contributor or Owner role)
- [ ] Azure CLI installed and configured (version 2.50 or later)
- [ ] VS Code installed
- [ ] Git installed and GitHub account created
- [ ] Fork this repository to personal GitHub account
- [ ] Verify no corporate proxy restrictions (or configure appropriate proxy settings)
- [ ] Basic familiarity with Azure Portal

#### For Instructors/Assistants:
- [ ] Prepare demo environment for ASR (Step 13)
- [ ] Test all Bicep templates and GitHub Actions workflows
- [ ] Prepare troubleshooting scenarios and solutions
- [ ] Set up monitoring for student environments
- [ ] Prepare backup slides for architecture explanations

### **Success Criteria**

#### Day 1:
- [ ] All Azure services deployed successfully
- [ ] 3-tier application is accessible via Public IP/Load Balancer
- [ ] Can login using Microsoft Entra ID
- [ ] Can create, read, update, delete blog posts
- [ ] Azure Monitor showing metrics from all VMs
- [ ] Log Analytics receiving logs from Azure Monitor Agent

#### Day 2:
- [ ] Successfully created backup recovery point
- [ ] Successfully restored data from backup
- [ ] System continues to function when one Web server is down
- [ ] System continues to function when one App server is down
- [ ] System continues to function when one DB server is down
- [ ] Successfully failed over to secondary region using ASR
- [ ] Application is functional in secondary region

### **Troubleshooting Guide & FAQ**
(To be created separately - common issues and solutions)

### **Known Limitations and Workarounds**
- Application Gateway vs Standard Load Balancer: Explain why SLB is used for time constraints
- Azure Files vs Blob Storage: Document use cases and tradeoffs
- PaaS alternatives: Provide comparison for future workshops

### **Post-Workshop Resources**
- Self-study materials for condensing to 4-hour version
- Links to Azure documentation
- Suggested next workshops (PaaS, Application Gateway, etc.)
- Certification paths (AZ-104, AZ-305)

## Notes for 4-hour condensed version (Future)

The following elements should be pre-deployed or automated:
- Complete infrastructure deployment via Bicep (pre-deployed or one-click)
- Application tier configuration automated via GitHub Actions
- ASR replication pre-configured (instructor demonstration only)
- Steps 11-12 moved to optional/homework

Focus areas for 4-hour version:
- Understanding the architecture (pre-deployed)
- Monitoring and Log Analytics
- Backup/Restore
- One failure scenario (Web tier only)
- ASR demonstration by instructor
 



