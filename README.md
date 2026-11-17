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


---
# AWS Disaster Recovery (DR) Drill & Automated Failover Runbook

An end-to-end Disaster Recovery (DR) architecture and automated failover runbook built with **Terraform**, **Bash**, **PostgreSQL (`pg_dump` / `pg_restore`)**, **AWS S3 (Versioning & Cross-Region Replication)**, and **Amazon RDS (Multi-AZ & Automated Snapshots)**.

## How It Works & Key Metrics
* **Architecture:** Replicates live PostgreSQL database data and S3 backups from a primary region (`ap-south-1` Mumbai) to a DR region (`ap-southeast-1` Singapore).
* **RTO (Recovery Time Objective):** Time elapsed from primary database failure to full recovery of live API traffic.
* **RPO (Recovery Point Objective):** Quantifies unbacked record loss between the last snapshot and the system crash.

## Repository Structure
* `app/server.py`: Live Python HTTP API reading from PostgreSQL.
* `terraform/main.tf`: Multi-region S3 Cross-Region Replication (CRR), IAM roles, and Multi-AZ RDS blueprint.
* `scripts/backup.sh`, `scripts/failover-restore.sh`, `scripts/dr-drill.sh`: Automation scripts for backups, failover recovery, and drills.

## Step-by-Step Guide to Run This Project
1. **Prerequisites:** Ensure Ubuntu/WSL2 has Docker, AWS CLI (`aws configure`), Terraform, Python 3, and `postgresql-client` installed.
2. **Validate Terraform:** Run `terraform init -backend=false` and `terraform validate` inside the `terraform/` directory.
3. **Start Primary DB & API:** Spin up PostgreSQL 16 via Docker, populate initial sample customer orders, and launch the Python API on port 8090.
4. **Execute Backup & Failover Drill:** Run the backup script to create S3 buckets and sync data, insert post-backup test orders, simulate a primary database crash, and execute `failover-restore.sh` to measure RTO and RPO.
5. **Clean Up:** Remove local Docker containers and clean up temporary AWS S3 buckets.

# AWS Disaster Recovery (DR) Drill & Automated Failover Runbook

An end-to-end Disaster Recovery (DR) architecture and automated failover runbook utilizing Terraform, Bash, PostgreSQL, AWS S3 cross-region replication, and Amazon RDS.

---

## Quick Start (Standalone S3 Cross-Region Drill)

1. **Validate Terraform Infrastructure:**
   ```bash
   cd terraform
   terraform init -backend=false
   terraform validate
   ```

2. **Execute DR Drill:**
   ```bash
   cd ..
   chmod +x scripts/dr-drill.sh
   ./scripts/dr-drill.sh
   ```

---

## Full Docker PostgreSQL + Live API Failover Runbook

To execute the database disaster simulation with the live HTTP API (`http://localhost:8090/orders`), `pg_dump` backups across AWS S3 regions (`ap-south-1` to `ap-southeast-1`), and automated `pg_restore` recovery:

### 1. Start Primary PostgreSQL & Seed Data
```bash
docker run -d --name prod-postgres \
  -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=ProdSecret2026! -e POSTGRES_DB=ordersdb \
  -p 5432:5432 postgres:16-alpine

sleep 5
PGPASSWORD=ProdSecret2026! psql -h 127.0.0.1 -U postgres -d ordersdb << 'SQL'
CREATE TABLE customer_orders (
    id SERIAL PRIMARY KEY,
    order_id VARCHAR(32) NOT NULL,
    customer_name VARCHAR(64) NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
INSERT INTO customer_orders (order_id, customer_name, amount)
SELECT 'ORD-' || LPAD(g::text, 6, '0'), 'Customer_' || g, 50.00
FROM generate_series(1, 5000) AS g;
SQL
```

### 2. Launch Live Orders API (`:8090`)
```bash
python3 -m venv .venv && source .venv/bin/activate
pip install psycopg2-binary
nohup python3 app/server.py > /tmp/orders_api.log 2>&1 &
curl -s http://localhost:8090/orders
```

### 3. Back Up, Simulate Outage, and Restore
```bash
chmod +x scripts/backup.sh scripts/failover-restore.sh

TS=\$(date +%Y%m%d-%H%M%S)
P_BUCKET="kashyap-real-dr-mumbai-\$TS"
D_BUCKET="kashyap-real-dr-singapore-\$TS"
aws s3api create-bucket --bucket "\$P_BUCKET" --region ap-south-1 --create-bucket-configuration LocationConstraint=ap-south-1
aws s3api create-bucket --bucket "\$D_BUCKET" --region ap-southeast-1 --create-bucket-configuration LocationConstraint=ap-southeast-1

# Backup and replicate
./scripts/backup.sh "\(P_BUCKET" "\)D_BUCKET"

# Remove primary container to simulate failure
docker rm -f prod-postgres
curl -s http://localhost:8090/orders

# Restore from DR bucket
./scripts/failover-restore.sh "\$D_BUCKET"
curl -s http://localhost:8090/orders
```

### 4. Cleanup
```bash
docker rm -f dr-postgres && pkill -f app/server.py
aws s3 rb "s3://\$P_BUCKET" --force --region ap-south-1
aws s3 rb "s3://\$D_BUCKET" --force --region ap-southeast-1
```

---

## Live Proof of Execution

1. Timed Disaster Recovery Drill & RTO/RPO Audit Report:

<img width="1280" height="587" alt="1" src="https://github.com/user-attachments/assets/75cd95ee-628b-4aad-9c2e-363d855fae8b" />

2. Live Recovered API in Browser 'http://localhost:8090/orders':

<img width="1280" height="730" alt="2" src="https://github.com/user-attachments/assets/66dcc231-efa9-4cf9-b010-8ce1f6425b60" />


3. Terraform Multi-Region Infrastructure Validation (`terraform validate`)

<img width="1280" height="689" alt="3" src="https://github.com/user-attachments/assets/31c4e120-8a24-4439-847d-9dccd8518b4c" />

