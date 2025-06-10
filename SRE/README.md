## SLA, SLO, SLI

## 

Automated Incident Response **(AIR)** refers to the use of tools and workflows to detect, manage, and resolve incidents with minimal human intervention. **Opsgenie**, **PagerDuty**, and similar platforms are popular tools in this space, providing features like alerting, escalation policies, on-call management, and automation. 

Here's an overview:

### 🔧 Key Tools

#### **1. Opsgenie (by Atlassian)**

* **Primary Use**: Alerting and on-call management.
* **Key Features**:

  * Alert deduplication & enrichment
  * Escalation policies and routing rules
  * Native integrations (Jira, Datadog, AWS, etc.)
  * Incident timeline and postmortems
  * API & webhook support for automation

#### **2. PagerDuty**

* **Primary Use**: Incident response orchestration.
* **Key Features**:

  * Dynamic incident routing
  * Automated diagnostics & runbooks
  * Real-time collaboration (Slack, MS Teams)
  * Advanced analytics (MTTA, MTTR)
  * Event Intelligence (AI-driven signal-to-noise reduction)
  * Automation actions (e.g., auto-restart services)

### ⚙️ Typical Automated Incident Response Workflow

```plaintext
[Monitoring Tool (e.g., Datadog, CloudWatch)]
         ↓
   [Alert Triggered]
         ↓
[Opsgenie or PagerDuty receives alert]
         ↓
[Apply routing/escalation policies]
         ↓
[Notify on-call engineer via SMS, push, email, etc.]
         ↓
(Optional) [Trigger automation: runbook script, restart service]
         ↓
[Track resolution and create timeline/postmortem]
```

### 🤖 Examples of Automation

* **Auto-remediation**:

  * If disk usage > 90%, automatically clear cache using a predefined script.
* **Runbook execution**:

  * Attach runbooks to alert types, which trigger diagnostics or mitigations.
* **Integration with CI/CD**:

  * Auto-halt deployment pipelines on critical alerts.
* **ChatOps**:

  * Integrate with Slack to acknowledge or resolve incidents via bot commands.
* **Smart Escalation**:

  * Escalate to a secondary engineer if the first responder doesn't acknowledge in X minutes.


### ✅ Benefits

* Reduced MTTR (Mean Time to Recovery)
* Consistent and repeatable response processes
* Lower fatigue from alert storms via deduplication and suppression
* Faster root cause identification and resolution
* Post-incident insights for continuous improvement


### 🚨 When to Use AIR

Use automated incident response when:

* Your services are highly distributed/microservice-based.
* You need 24/7 coverage with minimal human overhead.
* You want to reduce manual toil and human error.
* You have defined SOPs that can be automated safely.

---

