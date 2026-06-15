---
title: "Day 0: Prerequisites"
---

# Day 0: Prerequisites

## What You Do On This Page

Before the workshop starts, or at the beginning of the workshop, confirm Azure Portal, Cloud Shell, Entra ID app registration permissions, VM quota, your GitHub repository copy, and your Admin Object ID.

| Item | Details |
|---|---|
| Audience | Learners in the 2-day workshop |
| Time | 30-45 minutes |
| Prerequisites | Azure subscription, GitHub account, browser |
| Done When | You have the values and permissions needed for the Day 1 Cloud Shell deployment |

## Architecture You Will Build

On Day 1, you deploy a 3-tier blog application on Azure IaaS. Internet HTTPS traffic reaches Application Gateway first, then flows to NGINX VMs in the Web tier, Express API VMs in the App tier, and a MongoDB replica set in the DB tier.

![Azure IaaS Workshop architecture diagram](../../assets/images/learners-portal/architecture.png)
*3-tier architecture built in the Azure IaaS Workshop*

VMs in each tier are distributed across Availability Zones. Load Balancers sit in front of the Web and App tiers, Azure Bastion provides private SSH access, NAT Gateway handles outbound internet traffic, and Azure Monitor / Log Analytics centralize monitoring data. Day 0 prepares the subscription, permissions, quota, and app registration values needed to build this environment.

## 1. Sign In To Azure Portal

1. Open [Azure Portal](https://portal.azure.com).
2. Sign in with the account you will use for the workshop.
3. Confirm that the account and directory in the top-right corner are correct.

![Azure Portal home screen](../../assets/screenshots/learners-portal/day0/Top.png)
*Azure Portal home screen*

**Expected Result:** Azure Portal home or dashboard is displayed.

**Checkpoint:** If you belong to multiple tenants, switch to the tenant used for the workshop.

## 2. Start Cloud Shell Once

Start Cloud Shell before Day 1 so the first-time storage setup does not slow down the deployment flow.

1. Select the Cloud Shell icon in the Azure Portal top bar.
2. Select Bash.
3. If first-time storage setup appears, follow the instructor's guidance.

![Starting Cloud Shell](../../assets/screenshots/learners-portal/day0/CloudShell.png)
*Starting Cloud Shell*

**Expected Result:** A Bash prompt is displayed.

**Checkpoint:** Cloud Shell startup, repository clone, SSH key creation, and SSL certificate creation are grouped at the start of Day 1 resource deployment. For Day 0, it is enough to complete the first-time Cloud Shell startup and storage setup.

## 3. Check Subscription And Quota

Run this in Cloud Shell Bash.

```bash
az account show --query "{subscription:name, subscriptionId:id, tenantId:tenantId}" -o table
```

Switch subscriptions if needed.

```bash
az account set --subscription "<SUBSCRIPTION_ID_OR_NAME>"
```

This workshop uses 6 Basv2-series VMs.

| VM Size | Count | vCPU Each | Total |
|---|---:|---:|---:|
| Standard_B2als_v2 (Web) | 2 | 2 | 4 |
| Standard_B2als_v2 (App) | 2 | 2 | 4 |
| Standard_B4as_v2 (DB) | 2 | 4 | 8 |
| **Total** | **6** |  | **16 vCPU** |

```bash
az vm list-usage --location japanwest \
  --query "[?contains(name.value, 'standardBASv2Family') || name.value=='cores'].{Name:name.localizedValue, Current:currentValue, Limit:limit}" \
  -o table
```

**Expected Result:** The Basv2 family or regional core limit has at least 16 available vCPUs.

**Checkpoint:** If quota is insufficient, ask the instructor. You may need a different region or a quota increase.

## 4. Check Resource Providers

```bash
for provider in Microsoft.Compute Microsoft.Network Microsoft.Storage Microsoft.KeyVault Microsoft.OperationalInsights Microsoft.Insights; do
  az provider show --namespace "$provider" --query "{namespace:namespace,state:registrationState}" -o table
done
```

If any provider is `NotRegistered`, register it according to the instructor's guidance.

```bash
az provider register --namespace Microsoft.Compute
```

**Expected Result:** Required providers show `Registered`.

## 5. Copy The GitHub Template Repository

1. Open [hironariy/Azure-IaaS-Workshop](https://github.com/hironariy/Azure-IaaS-Workshop).
2. Select **Use this template** > **Create a new repository**.
3. Choose your GitHub account or the assigned organization as the owner.
4. Use `Azure-IaaS-Workshop`, or the name specified by the instructor.
5. For visibility, use a setting that allows unauthenticated clone from Cloud Shell when your organization policy permits it. Public is recommended when allowed.

![Copying the GitHub template repository](../../assets/screenshots/learners-portal/day0/GitHubRepositoryCopy.png)
*Copying the GitHub template repository*

**Expected Result:** You have your own working repository.

**Checkpoint:** On Day 1, clone your own copy, not the template source.

## 6. Check Entra ID App Registration Permissions

To create app registrations in Microsoft Entra ID, you need one of the following.

| Permission Or Setting | Description |
|---|---|
| Application Developer | Role assigned by an IT administrator |
| Cloud Application Administrator | Role assigned by an IT administrator |
| Global Administrator | Tenant administrator |
| Users can register applications | Tenant setting allows users to create app registrations |

How to check:

1. Open Azure Portal > Microsoft Entra ID > App registrations.
2. Select **New registration**.
3. If the registration form appears, you have permission.

If you do not have permission, ask the instructor. The instructor may provide pre-created Client IDs.

![Navigating from Azure Portal home to Entra ID](../../assets/screenshots/learners-portal/day0/EntraId1.png)
*Navigating from Azure Portal home to Entra ID*

![Navigating to App registrations](../../assets/screenshots/learners-portal/day0/EntraId2.png)
*Navigating to App registrations*

## 7. Create The Frontend SPA App Registration

1. Open Microsoft Entra ID > App registrations > **New registration**.
2. Enter `BlogApp Frontend <your name or team name>` as the name.
3. Unless instructed otherwise, select **Accounts in this organizational directory only**.
4. For Redirect URI, select **Single-page application (SPA)** and enter `http://localhost:5173`.
5. Select Register.
6. On Overview, record **Application (client) ID** and **Directory (tenant) ID**.
7. Open **Owners** from the left menu.
8. Select **Add owners** and add the account you use for the workshop.
9. Confirm that your account appears in the Owners list.

![Initial app registration screen](../../assets/screenshots/learners-portal/day0/AppRegistration1.png)
*Initial app registration screen*

![Checking client ID and tenant ID](../../assets/screenshots/learners-portal/day0/AppRegistration2.png)
*Checking client ID and tenant ID*

![Configuring app owners](../../assets/screenshots/learners-portal/day0/AppRegistration3.png)
*Configuring app owners*

**Expected Result:** You have the Frontend Client ID and your account appears as an owner.

**Checkpoint:** The platform must be SPA. If you select Web, MSAL.js authentication can fail with `AADSTS9002326`. In some tenants, creating the app registration does not automatically make you an owner; add yourself now so you can find and modify it later.

## 8. Create The Backend API App Registration

1. Open App registrations > **New registration**.
2. Enter `BlogApp API <your name or team name>` as the name.
3. Leave Redirect URI empty and register.
4. On Overview, record **Application (client) ID**.
5. Open **Expose an API** from the left menu.
6. Select **Add a scope** and save the default Application ID URI.
7. Enter `access_as_user` as the scope name.
8. Select **Admins and users** for who can consent.
9. Enter an admin consent display name and description, then add the scope.
10. Open **Owners** from the left menu.
11. Select **Add owners** and add the account you use for the workshop.
12. Confirm that your account appears in the Owners list.

![Exposing an API in the backend API app registration](../../assets/screenshots/learners-portal/day0/ExposeAnApi.png)
*Exposing an API in the backend API app registration*

**Expected Result:** You have the Backend API Client ID, the `access_as_user` scope exists, and your account appears as an owner.

**Checkpoint:** Add yourself as an owner here too. Without an owner, it can be hard to find the app later through ownership filters.

## 9. Add API Permission To The Frontend App

1. Open the Frontend SPA app registration.
2. Select **API permissions** > **Add a permission**.
3. From **APIs my organization uses** or **My APIs**, select `BlogApp API <your name or team name>`.
4. Select `access_as_user` and add the permission.
5. Grant admin consent only if you have administrator rights and the instructor tells you to do so.

![Adding API permission to the frontend app registration](../../assets/screenshots/learners-portal/day0/ApiPermission.png)
*Adding API permission to the frontend app registration*

**Expected Result:** The frontend app has the delegated permission for the backend API.

## 10. Get Your Admin Object ID

Day 1 Bicep deployment uses your Admin Object ID to grant Key Vault management rights to your Entra ID user. This is your signed-in user's Entra object ID, not an app registration Client ID.

Run this in Cloud Shell Bash.

```bash
az ad signed-in-user show --query id -o tsv
```

Record the displayed value as **Admin Object ID**.

For a readable check, run:

```bash
az ad signed-in-user show \
  --query "{displayName:displayName,userPrincipalName:userPrincipalName,objectId:id}" \
  -o table
```

**Expected Result:** You have your Entra ID object ID.

**Checkpoint:** Confirm that the Tenant ID from `az account show` matches the tenant where you created the app registrations. If this command fails because of tenant policy or permissions, ask the instructor.

## 11. Record Values For Day 1

| Value | Where To Get It | Day 1 Parameter |
|---|---|---|
| Tenant ID | Any app registration Overview or `az account show` | `entraTenantId` |
| Backend API Client ID | Backend API app registration Overview | `entraClientId` |
| Frontend SPA Client ID | Frontend SPA app registration Overview | `entraFrontendClientId` |
| Admin Object ID | Step 10 on this page | `adminObjectId` |

**Checkpoint:** Client IDs and Tenant ID are identifiers, but do not casually push them in notes to a public repository. Never record passwords or secrets.

## Next

Continue to [Day 1: Azure resource deployment](day-1-deployment-checklist.md).

Previous page: [Learner quickstart](learner-quickstart.md)

When stuck: [Learner portal](../index.md) / [Troubleshooting runbook](../operations/troubleshooting-runbook.md)