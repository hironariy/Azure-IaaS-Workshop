---
title: "Disaster Recovery Guide"
---

# Disaster Recovery Guide

## What You Do On This Page

Review the BCDR concepts used in this workshop: Azure Backup for recovery points, Azure Site Recovery for failover orchestration, and the safety rules for test failover.

| Item | Details |
|---|---|
| Audience | Learners who want the background behind Day 2 BCDR tasks |
| Time | 15-25 minutes |
| Prerequisites | Day 1 environment and Day 2 checklist context |
| Done When | You can explain backup, restore, replication, failover, test failover, RPO, and RTO |

## 1. Workshop Strategy

| Capability | Workshop Use |
|---|---|
| Azure Backup | Create recovery points and review restore options for VMs |
| Azure Site Recovery | Review or demo replication and test failover |
| HA testing | Stop one VM at a time and observe Application Gateway, Load Balancer, and MongoDB behavior |

For this IaaS workshop, Web and App tiers are easier to reason about because they are mostly stateless. DB tier failover requires more care because MongoDB replica set behavior and data consistency matter.

## 2. Azure Backup Pattern

1. Create a Recovery Services vault in the workload region.
2. Enable Backup for selected workshop VMs.
3. Run on-demand backup when the instructor tells you to.
4. Confirm restore points.
5. Review Restore VM options, and only create restored VMs when instructed.

**Good Outcome:** Learners can explain what is protected, where restore points are visible, and why production restores should be validated on new resources first.

## 3. Azure Site Recovery Pattern

1. Use Recovery Services vault > Site Recovery.
2. Enable replication for representative VMs or instructor-selected tiers.
3. Review target region and VNet/subnet mapping.
4. Wait for initial replication or switch to instructor demo.
5. Run test failover only into an isolated test network.
6. Clean up test failover resources.

**Good Outcome:** Learners can explain the difference between replication health, test failover, cleanup, planned failover, and unplanned failover.

## 4. Database Tier Considerations

MongoDB replica sets help with node or zonal failures, but regional DR requires a plan.

- If DB VMs are replicated with ASR, start DB first in a recovery plan.
- Validate replica set health and primary election after failover.
- If the workshop keeps DB regional DR as a design exercise, focus hands-on ASR on Web/App or representative VMs.

## 5. RPO And RTO

| Term | Meaning | Workshop Question |
|---|---|---|
| RPO | Maximum acceptable data loss | How much data could be lost between backups or replication points? |
| RTO | Maximum acceptable outage duration | How long can the app be unavailable during restore or failover? |

Backup-heavy recovery is simpler but often has larger RTO. Replication/failover can reduce RTO, but it needs more design and validation.

## 6. Safety Checklist

- Define RPO and RTO for the scenario.
- Confirm backups complete before discussing restore.
- Run test failover in an isolated network.
- Clean up test failover resources.
- Confirm all stopped VMs are running again.
- Do not leave duplicate restored VMs unless the instructor explicitly wants them.

## Related Pages

- Main exercise: [Day 2: Resiliency checklist](../learner/day-2-resiliency-checklist.md)
- Symptom-based help: [Troubleshooting runbook](troubleshooting-runbook.md)
- Commands and names: [Quick reference](../reference/quick-reference-card.md)

Back to the [learner portal](../index.md)