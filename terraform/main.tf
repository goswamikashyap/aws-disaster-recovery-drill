terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  alias  = "primary"
  region = "ap-south-1"
}

provider "aws" {
  alias  = "dr"
  region = "ap-southeast-1"
}

variable "project_prefix" {
  default = "kashyap-dr-drill-2026"
}

# 1. Primary S3 Bucket (Mumbai - ap-south-1) with Versioning
resource "aws_s3_bucket" "primary_data" {
  provider      = aws.primary
  bucket        = "${var.project_prefix}-primary"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "primary_versioning" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 2. Disaster Recovery S3 Bucket (Singapore - ap-southeast-1) with Versioning
resource "aws_s3_bucket" "dr_replica" {
  provider      = aws.dr
  bucket        = "${var.project_prefix}-replica"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "dr_versioning" {
  provider = aws.dr
  bucket   = aws_s3_bucket.dr_replica.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 3. IAM Role & Policy for S3 Cross-Region Replication (CRR)
resource "aws_iam_role" "replication_role" {
  provider = aws.primary
  name     = "${var.project_prefix}-s3-crr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "replication_policy" {
  provider = aws.primary
  name     = "${var.project_prefix}-s3-crr-policy"
  role     = aws_iam_role.replication_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        Resource = [aws_s3_bucket.primary_data.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
        Resource = ["${aws_s3_bucket.primary_data.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
        Resource = ["${aws_s3_bucket.dr_replica.arn}/*"]
      }
    ]
  })
}

# 4. Cross-Region Replication Rule (Mumbai -> Singapore)
resource "aws_s3_bucket_replication_configuration" "crr" {
  provider   = aws.primary
  depends_on = [aws_s3_bucket_versioning.primary_versioning]
  role       = aws_iam_role.replication_role.arn
  bucket     = aws_s3_bucket.primary_data.id

  rule {
    id     = "replicate-critical-data-to-dr"
    status = "Enabled"
    destination {
      bucket        = aws_s3_bucket.dr_replica.arn
      storage_class = "STANDARD_IA"
    }
  }
}

# 5. Production RDS PostgreSQL Instance (Multi-AZ + Automated Backups)
resource "aws_db_instance" "prod_db" {
  provider                  = aws.primary
  identifier                = "${var.project_prefix}-db"
  engine                    = "postgres"
  engine_version            = "16.3"
  instance_class            = "db.t3.micro"
  allocated_storage         = 20
  storage_encrypted         = true
  db_name                   = "appdb"
  username                  = "dbadmin"
  password                  = "ChangeMeInSecretsMgr2026!"
  multi_az                  = true
  backup_retention_period   = 7
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_prefix}-final-snap"
}
