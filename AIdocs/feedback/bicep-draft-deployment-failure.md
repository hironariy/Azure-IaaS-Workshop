---
feedback_date: 2025-12-08
subject: Draft bicep deployment failure report
reviewer: Hironari Yamada
focus_areas: [technical_accuracy, azure_best_practices, implementation_clarity]
---

I attempted to deploy the Bicep templates, materials/bicep/main.bicep as per the instructions, materials/bicep/README.md, but encountered a deployment failure. Here are the details:

1. **What deployments are failing?**
  Failed deployments:
    - main
    - deploy-load-balancer
    - deploy-bastion
    - deploy-db-tier
    - deploy-app-tier

2. **Error Messages Observed:**

  - For `deploy-load-balancer`:
    Error messsage is following:
    ```JSON
    {
        "code": "DeploymentFailed",
        "target": "/subscriptions/78d2b28b-2bad-42b5-b773-6846e2da2866/resourceGroups/rg-workshop-test/providers/Microsoft.Resources/deployments/deploy-load-balancer",
        "message": "At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/arm-deployment-operations for usage details.",
        "details": [
            {
            "code": "LoadBalancerFrontendIPConfigCannotHaveZoneWhenReferencingPublicIPAddress",
            "message": "Load balancer frontendIPConfiguration /subscriptions/78d2b28b-2bad-42b5-b773-6846e2da2866/resourceGroups/rg-workshop-test/providers/Microsoft.Network/loadBalancers/lbe-blogapp-prod/frontendIPConfigurations/frontend-web has 1 zone specified and is referencing a publicIPAddress /subscriptions/78d2b28b-2bad-42b5-b773-6846e2da2866/resourceGroups/rg-workshop-test/providers/Microsoft.Network/publicIPAddresses/pip-lb-blogapp-prod. Networking supports zones only for frontendIpconfigurations which reference a subnet."
            }
        ]
    }
    ```

    Detailed Error Logs:
    ```JSON
    {
        "code": "LoadBalancerFrontendIPConfigCannotHaveZoneWhenReferencingPublicIPAddress",
        "message": "Load balancer frontendIPConfiguration /subscriptions/78d2b28b-2bad-42b5-b773-6846e2da2866/resourceGroups/rg-workshop-test/providers/Microsoft.Network/loadBalancers/lbe-blogapp-prod/frontendIPConfigurations/frontend-web has 1 zone specified and is referencing a publicIPAddress /subscriptions/78d2b28b-2bad-42b5-b773-6846e2da2866/resourceGroups/rg-workshop-test/providers/Microsoft.Network/publicIPAddresses/pip-lb-blogapp-prod. Networking supports zones only for frontendIpconfigurations which reference a subnet.",
        "details": []
    }
    ```

    - For `deploy-bastion`:
    Error message is following:
    ```JSON
    {
        "code": "DeploymentOutputEvaluationFailed",
        "target": "/subscriptions/78d2b28b-2bad-42b5-b773-6846e2da2866/resourceGroups/rg-workshop-test/providers/Microsoft.Resources/deployments/deploy-bastion",
        "message": "Unable to evaluate template outputs: 'bastionFqdn'. Please see error details and deployment operations. Please see https://aka.ms/arm-common-errors for usage details.",
        "details": [
            {
            "code": "DeploymentOutputEvaluationFailed",
            "target": "bastionFqdn",
            "message": "The template output 'bastionFqdn' is not valid: The language expression property 'dnsSettings' doesn't exist, available properties are 'provisioningState, resourceGuid, ipAddress, publicIPAddressVersion, publicIPAllocationMethod, idleTimeoutInMinutes, ipTags, ddosSettings'.."
            }
        ]
    }
    ```

    Deployment screen shows 2 Public IPs and 1 Bastion Host created but following error message is shown:
    ```JSON
    {
        "code": "DeploymentOutputEvaluationFailed",
        "target": "/subscriptions/78d2b28b-2bad-42b5-b773-6846e2da2866/resourceGroups/rg-workshop-test/providers/Microsoft.Resources/deployments/deploy-bastion",
        "message": "Unable to evaluate template outputs: 'bastionFqdn'. Please see error details and deployment operations. Please see https://aka.ms/arm-common-errors for usage details.",
        "details": [
            {
            "code": "DeploymentOutputEvaluationFailed",
            "target": "bastionFqdn",
            "message": "The template output 'bastionFqdn' is not valid: The language expression property 'dnsSettings' doesn't exist, available properties are 'provisioningState, resourceGuid, ipAddress, publicIPAddressVersion, publicIPAllocationMethod, idleTimeoutInMinutes, ipTags, ddosSettings'.."
            }
        ]
    }
    ```

    - For `deploy-db-tier`:
    Error message is following:
    ```JSON
    {
        "code": "DeploymentFailed",
        "target": "/subscriptions/78d2b28b-2bad-42b5-b773-6846e2da2866/resourceGroups/rg-workshop-test/providers/Microsoft.Resources/deployments/deploy-db-tier",
        "message": "At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/arm-deployment-operations for usage details.",
        "details": [
            {
            "code": "InvalidTemplateDeployment",
            "message": "The template deployment 'deploy-vm-db-az2' is not valid according to the validation procedure. The tracking id is '9e48d8dc-4899-42c7-9f84-471a72326889'. See inner errors for details."
            },
            {
            "code": "InvalidTemplateDeployment",
            "message": "The template deployment 'deploy-vm-db-az1' is not valid according to the validation procedure. The tracking id is '04ec110c-9cf5-4b9a-94f2-00e146ba3342'. See inner errors for details."
            }
        ]
    }
    ```

    Detailed Error Logs for deploy-vm-db-az1:
    ```JSON
    {
        "code": "InvalidTemplateDeployment",
        "message": "The template deployment 'deploy-vm-db-az1' is not valid according to the validation procedure. The tracking id is '04ec110c-9cf5-4b9a-94f2-00e146ba3342'. See inner errors for details.",
        "details": [
            {
            "code": "InvalidParameter",
            "target": "imageReference",
            "message": "The following list of images referenced from the deployment template are not found: Publisher: Canonical, Offer: 0001-com-ubuntu-server-noble, Sku: 24_04-lts-gen2, Version: latest. Please refer to https://docs.microsoft.com/en-us/azure/virtual-machines/windows/cli-ps-findimage for instructions on finding available images."
            }
        ]
    }
    ```

    Detailed Error Logs for deploy-vm-db-az2:
    ```JSON
    {
        "code": "InvalidTemplateDeployment",
        "message": "The template deployment 'deploy-vm-db-az2' is not valid according to the validation procedure. The tracking id is '9e48d8dc-4899-42c7-9f84-471a72326889'. See inner errors for details.",
        "details": [
            {
            "code": "InvalidParameter",
            "target": "imageReference",
            "message": "The following list of images referenced from the deployment template are not found: Publisher: Canonical, Offer: 0001-com-ubuntu-server-noble, Sku: 24_04-lts-gen2, Version: latest. Please refer to https://docs.microsoft.com/en-us/azure/virtual-machines/windows/cli-ps-findimage for instructions on finding available images."
            }
        ]
    }
    ```

    - For`deploy-app-tier`:
    Error message is following:
    ```JSON
    {
        "code": "DeploymentFailed",
        "target": "/subscriptions/78d2b28b-2bad-42b5-b773-6846e2da2866/resourceGroups/rg-workshop-test/providers/Microsoft.Resources/deployments/deploy-app-tier",
        "message": "At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/arm-deployment-operations for usage details.",
        "details": [
            {
            "code": "InvalidTemplateDeployment",
            "message": "The template deployment 'deploy-vm-app-az2' is not valid according to the validation procedure. The tracking id is '8989f393-3b0f-40b2-ad9a-255a09d30422'. See inner errors for details."
            },
            {
            "code": "InvalidTemplateDeployment",
            "message": "The template deployment 'deploy-vm-app-az1' is not valid according to the validation procedure. The tracking id is '549a5393-8781-47d8-b101-d3857429519c'. See inner errors for details."
            }
        ]
    }
    ```

    Detailed Error Logs for deploy-vm-app-az1:
    ```JSON
    {
        "code": "InvalidTemplateDeployment",
        "message": "The template deployment 'deploy-vm-app-az1' is not valid according to the validation procedure. The tracking id is '549a5393-8781-47d8-b101-d3857429519c'. See inner errors for details.",
        "details": [
            {
            "code": "InvalidParameter",
            "target": "imageReference",
            "message": "The following list of images referenced from the deployment template are not found: Publisher: Canonical, Offer: 0001-com-ubuntu-server-noble, Sku: 24_04-lts-gen2, Version: latest. Please refer to https://docs.microsoft.com/en-us/azure/virtual-machines/windows/cli-ps-findimage for instructions on finding available images."
            }
        ]
    }
    ```

    Detailed Error Logs for deploy-vm-app-az2:
    ```JSON
    {
        "code": "InvalidTemplateDeployment",
        "message": "The template deployment 'deploy-vm-app-az2' is not valid according to the validation procedure. The tracking id is '8989f393-3b0f-40b2-ad9a-255a09d30422'. See inner errors for details.",
        "details": [
            {
            "code": "InvalidParameter",
            "target": "imageReference",
            "message": "The following list of images referenced from the deployment template are not found: Publisher: Canonical, Offer: 0001-com-ubuntu-server-noble, Sku: 24_04-lts-gen2, Version: latest. Please refer to https://docs.microsoft.com/en-us/azure/virtual-machines/windows/cli-ps-findimage for instructions on finding available images."
            }
        ]
    }
    ```
3. **Other Messages Observed:**

I found error messages in the terminal as following:
```
, publicIPAllocationMethod, idleTimeoutInMinutes, ipTags, ddosSettings'.."}]}]},{"code":"ResourceDeploymentFailure","target":"/subscriptions/78d2b28b-2bad-42b5-b773-6846e2da2866/resourceGroups/rg-workshop-test/providers/Microsoft.Resources/deployments/deploy-load-balancer","message":"The resource write operation failed to complete successfully, because it reached terminal provisioning state 'Failed'.","details":[{"code":"DeploymentFailed","target":"/subscriptions/78d2b28b-2bad-42b5-b773-6846e2da2866/resourceGroups/rg-workshop-test/providers/Microsoft.Resources/deployments/deploy-load-balancer","message":"At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/arm-deployment-operations for usage details.","details":[{"code":"LoadBalancerFrontendIPConfigCannotHaveZoneWhenReferencingPublicIPAddress","message":"Load balancer frontendIPConfiguration /subscriptions/78d2b28b-2bad-42b5-b773-6846e2da2866/resourceGroups/rg-workshop-test/providers/Microsoft.Network/loadBalancers/lbe-blogapp-prod/frontendIPConfigurations/frontend-web has 1 zone specified and is referencing a publicIPAddress /subscriptions/78d2b28b-2bad-42b5-b773-6846e2da2866/resourceGroups/rg-workshop-test/providers/Microsoft.Network/publicIPAddresses/pip-lb-blogapp-prod. Networking supports zones only for frontendIpconfigurations which reference a subnet.","details":[]}]}]}]}}
```
