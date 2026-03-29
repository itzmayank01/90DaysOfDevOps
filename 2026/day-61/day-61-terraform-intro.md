# Day 61 — Introduction to Terraform and Your First AWS Infrastructure

## Overview 

Today marked the beginning of my Infrastructure as Code journey with **Terraform**. Instead of clicking around in the AWS console, I defined, provisioned, and destroyed real AWS resources — an S3 bucket and an EC2 instance — using nothing but `.tf` files and a terminal.

---

## Task 1: Understanding Infrastructure as Code

### What is IaC and why does it matter in DevOps?

Infrastructure as Code means managing and provisioning cloud resources through code files instead of manual GUI interactions. In DevOps, this matters because it brings the same discipline we apply to application code — version control, peer review, automation, repeatability — to the infrastructure layer. If your app deployment is automated but your server setup is done manually, you still have a fragile pipeline.

### Problems IaC solves vs. manual AWS Console clicks

When you create resources manually through the AWS console, you introduce **drift** — over time nobody knows exactly what exists, why it was created, or how to recreate it. IaC solves this by making infrastructure:
- **Reproducible** — run the same code in any region or account and get the same result
- **Auditable** — changes are tracked in Git, not buried in someone's memory
- **Recoverable** — if something breaks, you can tear down and recreate in minutes
- **Consistent** — no human error from clicking through wizards

### Terraform vs. CloudFormation vs. Ansible vs. Pulumi

| Tool | Type | Language | Cloud |
|---|---|---|---|
| **Terraform** | Provisioning | HCL (declarative) | Any (AWS, GCP, Azure, etc.) |
| **CloudFormation** | Provisioning | JSON/YAML | AWS only |
| **Ansible** | Configuration Management | YAML (procedural) | Agentless, any |
| **Pulumi** | Provisioning | Python/TypeScript/Go | Any |

Terraform wins on **portability** and **community ecosystem** (Terraform Registry). CloudFormation is tightly integrated with AWS but locks you in. Ansible is better suited for configuring what's *inside* servers (packages, files, services), not creating the servers themselves. Pulumi offers the same cloud-agnostic approach but uses general-purpose programming languages instead of HCL.

### What does "declarative" and "cloud-agnostic" mean?

**Declarative** means I describe *what* I want the end state to be, not *how* to get there. I write `resource "aws_s3_bucket" "my_bucket" {}` and Terraform figures out the API calls, ordering, and dependencies. In contrast, a script where you call `aws s3api create-bucket`, then `aws s3api put-bucket-policy`, etc. is *imperative* — you specify every step.

**Cloud-agnostic** means the same Terraform workflow (`init → plan → apply → destroy`) works whether your provider is AWS, GCP, Azure, or even GitHub or Datadog. You swap the provider block and your core skills transfer.

---

## Task 2: Install Terraform and Configure AWS

### Installing Terraform (Linux/Ubuntu)

```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

Verifying the installation:

```bash
terraform -version
# Terraform v1.x.x on linux_amd64
```

### Configuring AWS CLI

```bash
aws configure
# AWS Access Key ID [None]: <your-access-key>
# AWS Secret Access Key [None]: <your-secret-key>
# Default region name [None]: ap-south-1
# Default output format [None]: json
```

Verifying AWS access:

```bash
aws sts get-caller-identity
```

Output confirms the AWS Account ID, User ID, and ARN — meaning the credentials are valid and Terraform will be able to authenticate.

---

## Task 3: First Terraform Config — S3 Bucket

### Project structure

```bash
mkdir terraform-basics && cd terraform-basics
```

### `main.tf` — S3 bucket configuration

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "terraweek-mayank-2026"

  tags = {
    Name        = "TerraWeek-Bucket"
    Environment = "Dev"
  }
}
```

### Running the Terraform lifecycle

```bash
terraform init
```

**What `terraform init` does:** Downloads the AWS provider plugin from the Terraform Registry and stores it inside `.terraform/providers/`. The `.terraform/` directory contains the downloaded provider binaries, a lock file (`.terraform.lock.hcl`) that pins exact provider versions, and a modules cache if you're using modules. This is analogous to `npm install` or `pip install`.

```bash
terraform plan
```

Shows a preview of what will be created. The `+` symbols indicate new resources being added. Nothing touches AWS yet.

```bash
terraform apply
# Type 'yes' to confirm
```

Terraform called the AWS S3 API and created the bucket. Verified in the AWS S3 console ✅

---

## Task 4: Adding an EC2 Instance

Added to `main.tf`:

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0f5ee92e2d63afc18"  # Amazon Linux 2 — ap-south-1
  instance_type = "t2.micro"

  tags = {
    Name = "TerraWeek-Day1"
  }
}
```

```bash
terraform plan
# 1 to add, 0 to change, 0 to destroy
```

```bash
terraform apply
```

**How does Terraform know the S3 bucket already exists?**
Terraform reads the `terraform.tfstate` file before planning. It compares the desired state (what's in `.tf` files) against the recorded state (what's in `.tfstate`). Since the S3 bucket is already recorded in the state file as created, Terraform knows it exists and only needs to create the EC2 instance.

Verified the instance running with tag `TerraWeek-Day1` in the EC2 console ✅

---

## Task 5: Understanding the State File

### Inspecting the state

```bash
terraform show
# Prints human-readable output of all resources in state

terraform state list
# aws_instance.web
# aws_s3_bucket.my_bucket

terraform state show aws_s3_bucket.my_bucket
# Shows bucket ARN, region, hosted zone ID, tags, etc.

terraform state show aws_instance.web
# Shows instance ID, public IP, AMI, instance type, state, tags, etc.
```

### What does the state file store?

The `terraform.tfstate` file stores the full JSON representation of every resource Terraform manages — resource type, unique IDs (like `instance_id`, `bucket ARN`), all attributes (IP addresses, availability zones, tags), dependencies, and provider metadata. Essentially everything AWS returned at creation time.

### Why should you NEVER manually edit the state file?

The state file is the source of truth Terraform uses to calculate diffs. If you edit it manually and introduce incorrect values, Terraform's next `plan` will produce wrong diffs — it might try to destroy real resources or attempt to create duplicates. The correct way to fix state issues is via `terraform state mv`, `terraform state rm`, or `terraform import` commands.

### Why should the state file NOT be committed to Git?

The state file contains **sensitive information** — private IP addresses, ARNs, and potentially secrets depending on the resources. It also changes with every `apply`, which creates noisy commits. For team environments, the state should live in a **remote backend** (like an S3 bucket + DynamoDB lock table) so multiple engineers can share and lock it safely.

---

## Task 6: Modify, Plan, and Destroy

### Changing the EC2 tag

Updated in `main.tf`:

```hcl
tags = {
  Name = "TerraWeek-Modified"
}
```

```bash
terraform plan
```

**Understanding the plan symbols:**
| Symbol | Meaning |
|--------|---------|
| `+` | Resource will be **created** |
| `-` | Resource will be **destroyed** |
| `~` | Resource will be **updated in-place** |
| `-/+` | Resource will be **destroyed and recreated** |

For a tag change, Terraform shows `~` — this is an **in-place update**. Tags are mutable attributes that AWS can change without recreating the instance. If I had changed the AMI or instance type, it would show `-/+` (destroy and recreate).

```bash
terraform apply
```

Verified the tag changed to `TerraWeek-Modified` in the EC2 console ✅

### Destroying all resources

```bash
terraform destroy
# Type 'yes' to confirm
# aws_instance.web: Destroying...
# aws_s3_bucket.my_bucket: Destroying...
# Destroy complete! Resources: 2 destroyed.
```

Both the S3 bucket and EC2 instance are gone from the AWS console ✅

---

## Terraform Command Reference

| Command | What it does |
|---|---|
| `terraform init` | Initializes the working directory, downloads provider plugins |
| `terraform plan` | Shows a preview of changes without making them — "dry run" |
| `terraform apply` | Executes the plan and provisions/modifies real infrastructure |
| `terraform destroy` | Destroys all resources managed by the current state |
| `terraform show` | Prints human-readable view of current state |
| `terraform state list` | Lists all resources tracked in the state file |
| `terraform state show <resource>` | Shows detailed attributes of a specific resource |
| `terraform fmt` | Auto-formats `.tf` files to canonical HCL style |
| `terraform validate` | Checks syntax and config validity without connecting to AWS |

---

## Key Takeaways

1. **Terraform is declarative** — describe the desired end state, not the steps to get there
2. **The state file is critical** — never edit it manually, never commit it to Git
3. **`terraform plan` is your safety net** — always read it before applying
4. **Infrastructure is now version-controlled** — the `.tf` files are the source of truth
5. **Destroy is just as easy as create** — one command tears down everything cleanly

---

## .gitignore additions

```gitignore
# Terraform
*.tfstate
*.tfstate.backup
.terraform/
.terraform.lock.hcl
```

---

## Screenshots

> 📁 All screenshots are stored in the `screenshots/` folder.

| # | Description | File |
|---|---|---|
| 1 | `terraform -version` output confirming installation | `screenshots/01-terraform-version.png` |
| 2 | `aws sts get-caller-identity` confirming AWS credentials | `screenshots/02-aws-identity.png` |
| 3 | `terraform init` downloading AWS provider | `screenshots/03-terraform-init.png` |
| 4 | `terraform plan` showing S3 bucket to be created | `screenshots/04-plan-s3.png` |
| 5 | `terraform apply` creating the S3 bucket | `screenshots/05-apply-s3.png` |
| 6 | S3 bucket visible in AWS Console | `screenshots/06-s3-console.png` |
| 7 | `terraform plan` showing EC2 instance to be created | `screenshots/07-plan-ec2.png` |
| 8 | `terraform apply` creating the EC2 instance | `screenshots/08-apply-ec2.png` |
| 9 | EC2 instance running with tag `TerraWeek-Day1` in AWS Console | `screenshots/09-ec2-console.png` |
| 10 | `terraform state list` output | `screenshots/10-state-list.png` |
| 11 | `terraform show` output | `screenshots/11-terraform-show.png` |
| 12 | `terraform plan` showing `~` in-place tag update | `screenshots/12-plan-tag-update.png` |
| 13 | EC2 tag updated to `TerraWeek-Modified` in AWS Console | `screenshots/13-ec2-tag-modified.png` |
| 14 | `terraform destroy` completing successfully | `screenshots/14-terraform-destroy.png` |
| 15 | AWS Console confirming both resources are deleted | `screenshots/15-console-empty.png` |

---

## References

- [Terraform Official Docs](https://developer.hashicorp.com/terraform/docs)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [90DaysOfDevOps Challenge](https://github.com/itzmayank01/90DaysOfDevOps)

---

*Day 61 of #90DaysOfDevOps | #TerraWeek | #DevOpsKaJosh | #TrainWithShubham*
