# AWS Disaster Recovery (DR) Drill & Automated Failover Runbook

An end-to-end Disaster Recovery (DR) architecture and timed failover runbook built with **Terraform**, **Bash**, **AWS S3 (Versioning & Cross-Region Replication)**, and **Amazon RDS (Multi-AZ & Automated Snapshots)**. It provisions multi-region backup infrastructure, simulates regional data loss, executes automated failover restoration, and measures **Recovery Time Objective (RTO)** and **Recovery Point Objective (RPO)**.

---

## Architecture & Failover Flow

```text
┌───────────────────────────────────────┐        ┌───────────────────────────────────────┐
│     Primary Region (ap-south-1)       │        │       DR Region (ap-southeast-1)      │
│                                       │  CRR   │                                       │
│  • S3 Primary Bucket (Versioned)      ├───────►│  • S3 Replica Bucket (Versioned)      │
│  • RDS PostgreSQL (Multi-AZ + Snaps)  │  Sync  │  • Automated Failover Target Bucket   │
└───────────────────┬───────────────────┘        └───────────────────┬───────────────────┘
                    │                                                │
           [Simulated Outage]                               [Scripted Restore]
                    │                                                │
                    ▼                                                ▼
         Primary Object Deleted                        Restores Payload & Verifies
         (Outage Timer Starts)                         RTO / RPO & 100% Integrity
```

---

## Key Engineering Highlights

* **Declarative Multi-Region Infrastructure (`terraform/main.tf`):**
  * **S3 Versioning & Cross-Region Replication (CRR):** Configures primary (`ap-south-1`) and disaster recovery (`ap-southeast-1`) buckets with object versioning and least-privilege IAM replication roles.
  * **High-Availability RDS Blueprint:** Defines an encrypted PostgreSQL Multi-AZ database instance with 7-day automated backup retention and final snapshot protection.
* **Timed Automated Recovery Runbook (`scripts/dr-drill.sh`):**
  * Simulates a production outage by deleting primary production data in Mumbai (`ap-south-1`).
  * Automates restoration from the Singapore (`ap-southeast-1`) replica, verifies payload integrity, calculates exact **RTO** and **RPO** timestamps, and purges versioned drill buckets cleanly.

---

## Repository Structure

```text
├── terraform/
│   └── main.tf             # Multi-region S3 CRR, IAM roles, and Multi-AZ RDS blueprint
├── scripts/
│   └── dr-drill.sh         # Timed end-to-end DR failover drill & RTO/RPO audit script
├── .gitignore
└── README.md
```

---

## Quick Start

1. **Validate the Terraform Infrastructure Blueprint:**
   ```bash
   cd terraform
   terraform init -backend=false
   terraform validate
   ```

2. **Execute the Timed Disaster Recovery Drill:**
   ```bash
   cd ..
   chmod +x scripts/dr-drill.sh
   ./scripts/dr-drill.sh
   ```

---

## Live Proof of Execution

### 1. Timed Disaster Recovery Drill & RTO/RPO Audit Report


### 2. Terraform Multi-Region Infrastructure Validation (`terraform validate`)
