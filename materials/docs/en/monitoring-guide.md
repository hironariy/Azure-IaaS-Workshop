# Monitoring Guide (Azure Monitor + Log Analytics)

This guide shows how to observe and troubleshoot the workshop environment using:
- **Azure Monitor** (metrics + platform logs)
- **Log Analytics** (querying logs with KQL)

## Scope

- **Infrastructure**: Application Gateway, Load Balancer, VMs (NGINX/Web + Node/App + MongoDB/DB)
- **Goal**: quickly answer “is it up?”, “what is slow?”, and “what failed?”

> Note: Some monitoring pieces may be “planned” for Infrastructure-as-Code in Bicep. This guide focuses on practical, manual enablement steps so the workshop can proceed regardless.

---

## 1. Create (or reuse) a Log Analytics workspace

1. In the Azure portal, search for **Log Analytics workspaces**.
2. Create a workspace in the same region as your primary deployment (recommended).
3. Name it with an environment suffix, e.g. `law-blogapp-dev`.

**AWS analogy:** Log Analytics workspace is conceptually similar to a centralized CloudWatch Logs destination + query layer.

---

## 2. Enable platform diagnostics to Log Analytics

### 2.1 Application Gateway diagnostics

Enable diagnostics so you can query:
- Access logs (who/what/latency)
- Performance logs
- Firewall logs (if WAF is used)

Steps (portal):
1. Open your **Application Gateway** resource.
2. Go to **Diagnostic settings**.
3. Create a setting that sends logs to your **Log Analytics workspace**.
4. Select relevant categories (Access/Performance).

### 2.2 Load Balancer diagnostics (if applicable)

If you rely on Load Balancer metrics/diagnostics:
1. Open the **Load Balancer** resource.
2. Configure diagnostics similarly, sending to the same workspace.

---

## 3. Collect VM logs and performance data

There are two common levels for VM monitoring:

### 3.1 Baseline: Metrics + Activity Log

- Use **Metrics** on each VM for CPU, disk, network
- Use **Activity Log** to track control-plane actions (start/stop, redeploy, updates)

This works immediately but doesn’t include OS logs.

### 3.2 Recommended: VM Insights (performance + dependency view)

1. In Azure portal, search for **Virtual Machines**.
2. Choose a VM, go to **Insights**.
3. Enable Insights and point it to your **Log Analytics workspace**.

Repeat for the web/app/db VMs.

---

## 4. What to look at during the workshop

### 4.1 “Is the service up?”

- Application Gateway backend health
- VM status (running, boot diagnostics)
- Load Balancer health probe status

### 4.2 “Why is it slow?”

- App Gateway access logs: look at request time and backend response time
- VM CPU (web/app) and disk latency (db)
- MongoDB performance counters (if you export them)

### 4.3 “What failed?”

- App Gateway logs: 4xx/5xx patterns
- Node/NGINX service logs on the VM
- OS syslog / Windows Event logs (depending on image)

---

## 5. Log Analytics: starter KQL queries

> These are intentionally generic. The exact tables depend on which diagnostics/agents you enabled.

### 5.1 Show recent events (sanity check)

```kusto
search *
| take 50
```

### 5.2 Find HTTP 5xx errors (gateway)

```kusto
search " 500 "
| take 100
```

### 5.3 VM heartbeat / agent presence

```kusto
Heartbeat
| summarize LastSeen=max(TimeGenerated) by Computer
| order by LastSeen desc
```

---

## 6. Operational tips (workshop-friendly)

- Use a **single workspace** per student environment to keep queries simple.
- Keep diagnostics settings names consistent (`to-law-blogapp`).
- When investigating issues, start from the edge (**Application Gateway**) and work inward (web → app → db).

---

## 7. Next steps (optional)

- Add Azure Monitor **alerts** (HTTP 5xx rate, backend health down, VM CPU high)
- Add **diagnostic settings via Bicep** so environments are consistently observable
