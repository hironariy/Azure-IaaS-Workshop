---
title: "Monitoring Guide"
---

# Monitoring Guide (Azure Monitor + Log Analytics)

## What You Do On This Page

Inspect the Azure IaaS environment deployed on Day 1 with Azure Monitor and Log Analytics. Start at Application Gateway and move inward through Web, App, and DB tiers.

| Item | Details |
|---|---|
| Audience | Learners checking monitoring after Day 1 deployment |
| Time | 30-45 minutes |
| Prerequisites | Day 1 resource deployment, application deployment, and DCR configuration are complete |
| Done When | You can check Application Gateway backend health, VM Heartbeat, and starter KQL queries |

## 1. Monitoring Overview

| Concern | Azure Location | AWS Analogy |
|---|---|---|
| Metrics | Azure Monitor Metrics | CloudWatch Metrics |
| Logs | Log Analytics workspace | CloudWatch Logs + Logs Insights |
| Control-plane operations | Activity log | Similar to CloudTrail for operations |
| VM guest data | Azure Monitor Agent + DCR | CloudWatch Agent |
| Entry-point health | Application Gateway backend health | ALB target health |

Day 1 Bicep creates the Log Analytics workspace and VM extensions. `scripts/configure-dcr.sh` creates the Data Collection Rule after Log Analytics tables initialize.

## 2. Check Health From The Entry Point

```bash
RESOURCE_GROUP="rg-blogapp-workshop"

az network application-gateway show-backend-health \
  --resource-group "$RESOURCE_GROUP" \
  --name agw-blogapp-prod \
  --query "backendAddressPools[].backendHttpSettingsCollection[].servers[].{address:address,health:health}" \
  -o table
```

**Expected Result:** Web tier backends are Healthy.

**Checkpoint:** If anything is Unhealthy, use the [troubleshooting runbook](troubleshooting-runbook.md).

## 3. Check VM Heartbeat

Open the Log Analytics workspace in Azure Portal, then run this in Logs.

![Navigating from Azure Portal home to Azure Monitor](../../assets/screenshots/learners-portal/day1/Top-to-monitor.png)
*Navigating from Azure Portal home to Azure Monitor*

```kusto
Heartbeat
| summarize LastSeen=max(TimeGenerated) by Computer
| order by LastSeen desc
```

![Running a Heartbeat query](../../assets/screenshots/learners-portal/day1/MonitorHeartBeat.png)
*Running a Heartbeat query*

**Expected Result:** Web, App, and DB VM names appear with `LastSeen`.

## 4. Check CPU And Memory Trends

```kusto
Perf
| where TimeGenerated > ago(1h)
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| summarize AvgCpuPercent=avg(CounterValue) by bin(TimeGenerated, 5m), Computer
| order by TimeGenerated asc
| render timechart
```

```kusto
Perf
| where TimeGenerated > ago(1h)
| where ObjectName == "Memory" and CounterName == "% Used Memory"
| summarize AvgMemoryUsedPercent=avg(CounterValue) by bin(TimeGenerated, 5m), Computer
| order by TimeGenerated asc
| render timechart
```

![CPU chart](../../assets/screenshots/learners-portal/day1/MonitorCpu.png)
*CPU chart*

**Expected Result:** CPU and memory utilization appear as per-VM line charts.

**Checkpoint:** If no data appears, run `Perf | take 20` to inspect available counters. If the graph does not appear, confirm that Chart view is selected in Logs.

## 5. Check Syslog Errors

```kusto
Syslog
| where SeverityLevel in ("err", "crit", "alert", "emerg")
| project TimeGenerated, Computer, Facility, SeverityLevel, SyslogMessage
| order by TimeGenerated desc
| take 50
```

**Expected Result:** You can inspect OS and service errors. No rows can be normal in a healthy environment.

## 6. Explore Application Gateway Logs

If diagnostic settings send Application Gateway logs to Log Analytics, start with:

```kusto
search "ApplicationGateway"
| order by TimeGenerated desc
| take 50
```

For HTTP 5xx patterns:

```kusto
search " 500 " or " 502 " or " 503 "
| order by TimeGenerated desc
| take 100
```

**Checkpoint:** Table names depend on diagnostic settings. Use `search * | take 50` first if unsure.

## 7. What To Watch During Day 2

| Exercise | Watch | Expected Observation |
|---|---|---|
| Web VM stop | Application Gateway backend health | One backend becomes Unhealthy; app continues |
| App VM stop | API traffic, VM Heartbeat | API continues or recovers quickly |
| DB VM stop | API traffic, Syslog, VM state | Temporary failures may occur; app stabilizes after recovery |
| ASR test failover | Recovery Services vault jobs | Test failover job and cleanup state |

## Common Issues

| Symptom | Check | Action |
|---|---|---|
| No Heartbeat | DCR was created and associated | Check `./scripts/configure-dcr.sh "$RESOURCE_GROUP"` |
| No Perf rows | Table initialization and counters | Wait a few minutes, run `Perf | take 20` |
| No App Gateway logs | Diagnostic settings | Enable sending Application Gateway logs to Log Analytics |
| VM does not recover after stop | VM power state | Start it with `az vm start` |

## Completion Criteria

- Application Gateway backend health is checked.
- Heartbeat is visible in Log Analytics.
- Perf or Syslog starter queries run.
- You can explain what to watch during Day 2 failure validation.

## Next

Continue to [Day 2: Resiliency checklist](../learner/day-2-resiliency-checklist.md).

Previous page: [Day 1: Application deployment](../learner/day-1-app-deployment.md)

When stuck: [Troubleshooting runbook](troubleshooting-runbook.md) / [Quick reference](../reference/quick-reference-card.md)

Back to the [learner portal](../index.md)