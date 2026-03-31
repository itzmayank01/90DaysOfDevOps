# Day 62 — Terraform Providers, Resources and Dependencies

## Overview

Yesterday I created standalone AWS resources. Today I built a **complete networking stack** — VPC, subnet, internet gateway, route table, security group, and an EC2 instance — and learned how Terraform automatically figures out the correct creation order using dependency graphs. Understanding dependencies is what separates a Terraform beginner from someone who can build production infrastructure.

---

## Task 1: Exploring the AWS Provider

### Project setup

```bash
mkdir terraform-aws-infra && cd terraform-aws-infra
```

### `providers.tf`

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
```

```bash
terraform init
```

**Output:** Terraform downloaded and installed the AWS provider version `5.x.x` from the Terraform Registry.

### Reading the lock file

```bash
cat .terraform.lock.hcl
```

The `.terraform.lock.hcl` file **pins the exact provider version** that was installed. It stores the version number, checksums (hashes), and constraints. When a teammate runs `terraform init`, they get the exact same provider version — not just any version that satisfies `~> 5.0`. This is the same concept as `package-lock.json` in Node.js or `Pipfile.lock` in Python. **Commit this file to Git.**

### Version constraint syntax explained

| Constraint | Meaning | Example versions allowed |
|---|---|---|
| `~> 5.0` | Any `5.x` but NOT `6.0` | `5.0`, `5.1`, `5.99` ✅ — `6.0` ❌ |
| `>= 5.0` | Version 5.0 or anything higher | `5.0`, `5.5`, `6.0`, `7.2` ✅ |
| `= 5.0.0` | Exactly version 5.0.0 only | Only `5.0.0` ✅ |

`~> 5.0` (pessimistic constraint) is the recommended approach — it allows patch and minor updates within a major version while preventing breaking changes from a major bump.

---

## Task 2: Building a VPC from Scratch

### `main.tf` — Complete networking stack

```hcl
# VPC — the isolated network container for all our resources
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "TerraWeek-VPC"
  }
}

# Subnet — a subdivision of the VPC for our resources to live in
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id        # implicit dependency on VPC
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "TerraWeek-Public-Subnet"
  }
}

# Internet Gateway — the door between the VPC and the public internet
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id                         # implicit dependency on VPC

  tags = {
    Name = "TerraWeek-IGW"
  }
}

# Route Table — defines where traffic goes (0.0.0.0/0 → internet gateway)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id                         # implicit dependency on VPC

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id       # implicit dependency on IGW
  }

  tags = {
    Name = "TerraWeek-RouteTable"
  }
}

# Route Table Association — connects the route table to the subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id            # implicit dependency on subnet
  route_table_id = aws_route_table.public_rt.id   # implicit dependency on route table
}
```

```bash
terraform plan
# Plan: 5 to add, 0 to change, 0 to destroy
```

```bash
terraform apply
# Type 'yes'
```

Verified in the AWS VPC console — all 5 resources visible and connected ✅

**CIDR breakdown:**
- `10.0.0.0/16` → 65,536 IPs for the VPC (entire private network)
- `10.0.1.0/24` → 256 IPs carved out for the public subnet

---

## Task 3: Understanding Implicit Dependencies

### How does Terraform know creation order?

Terraform reads your `.tf` files and builds an internal **dependency graph** by analyzing attribute references. When I write:

```hcl
vpc_id = aws_vpc.main.id
```

Terraform sees this reference and registers: *"the subnet depends on the VPC — create VPC first."* This is an **implicit dependency** — it happens automatically from the reference syntax, no extra configuration needed.

### What would happen if the subnet was created before the VPC?

The AWS API would return an error: `InvalidVpcID.NotFound` — because the VPC ID being passed doesn't exist yet. Terraform prevents this entirely by resolving the order before making any API calls.

### All implicit dependencies in this config

| Resource | Depends On | Via attribute |
|---|---|---|
| `aws_subnet.public` | `aws_vpc.main` | `vpc_id = aws_vpc.main.id` |
| `aws_internet_gateway.igw` | `aws_vpc.main` | `vpc_id = aws_vpc.main.id` |
| `aws_route_table.public_rt` | `aws_vpc.main` | `vpc_id = aws_vpc.main.id` |
| `aws_route_table.public_rt` | `aws_internet_gateway.igw` | `gateway_id = aws_internet_gateway.igw.id` |
| `aws_route_table_association.public_assoc` | `aws_subnet.public` | `subnet_id = aws_subnet.public.id` |
| `aws_route_table_association.public_assoc` | `aws_route_table.public_rt` | `route_table_id = aws_route_table.public_rt.id` |

**Creation order Terraform resolved:**
1. `aws_vpc.main` (no dependencies)
2. `aws_subnet.public`, `aws_internet_gateway.igw` (both depend only on VPC — can run in parallel)
3. `aws_route_table.public_rt` (depends on VPC + IGW)
4. `aws_route_table_association.public_assoc` (depends on subnet + route table)

---

## Task 4: Adding a Security Group and EC2 Instance

Added to `main.tf`:

```hcl
# Security Group — firewall rules for the EC2 instance
resource "aws_security_group" "web_sg" {
  name        = "TerraWeek-SG"
  description = "Allow SSH and HTTP inbound"
  vpc_id      = aws_vpc.main.id                    # implicit dependency on VPC

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"           # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "TerraWeek-SG"
  }
}

# EC2 Instance — our server inside the public subnet
resource "aws_instance" "main" {
  ami                         = "ami-0f5ee92e2d63afc18"   # Amazon Linux 2 — ap-south-1
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id       # implicit dependency on subnet
  vpc_security_group_ids      = [aws_security_group.web_sg.id]  # implicit dependency on SG
  associate_public_ip_address = true

  tags = {
    Name = "TerraWeek-Server"
  }
}
```

```bash
terraform apply
# Plan: 2 to add, 0 to change, 0 to destroy
```

EC2 instance running with a public IP in the correct subnet ✅
Security group attached with SSH and HTTP rules ✅

---

## Task 5: Explicit Dependencies with `depends_on`

Sometimes Terraform cannot detect a dependency because there is no direct attribute reference between two resources. For example, an S3 bucket for application logs should only be created after the EC2 instance is up — but there is no attribute from the instance used in the bucket config.

This is where `depends_on` comes in.

```hcl
# S3 bucket for application logs — no direct reference to EC2,
# but we want it created only after the instance is running
resource "aws_s3_bucket" "app_logs" {
  bucket = "terraweek-mayank-app-logs-2026"

  depends_on = [aws_instance.main]    # explicit dependency

  tags = {
    Name = "TerraWeek-AppLogs"
  }
}
```

### Visualizing the dependency graph

```bash
terraform graph | dot -Tpng > graph.png
```

Or paste `terraform graph` output into [webgraphviz.com](http://webgraphviz.com)

The graph clearly shows the dependency chain:
```
aws_vpc → aws_subnet → aws_route_table_association
aws_vpc → aws_internet_gateway → aws_route_table → aws_route_table_association
aws_vpc → aws_security_group → aws_instance → aws_s3_bucket
aws_subnet → aws_instance
```

### When would you use `depends_on` in real projects?

**Example 1 — IAM Role before EC2:** You create an IAM role and an EC2 instance separately. The instance needs the IAM role to be fully created and propagated before launch — but since you're not referencing the role ARN in the instance block (using instance profiles instead), Terraform won't detect the dependency. Use `depends_on = [aws_iam_role.ec2_role]`.

**Example 2 — RDS before Lambda:** A Lambda function connects to an RDS database. If the Lambda references the RDS endpoint via an environment variable, the dependency is implicit. But if the endpoint is stored in SSM Parameter Store and fetched at runtime, Terraform sees no reference — `depends_on = [aws_db_instance.main]` ensures RDS exists before Lambda is deployed.

---

## Task 6: Lifecycle Rules and Destroy

### Adding lifecycle to the EC2 instance

```hcl
resource "aws_instance" "main" {
  ami                         = "ami-0f5ee92e2d63afc18"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "TerraWeek-Server"
  }
}
```

After changing the AMI ID and running `terraform plan`, Terraform shows it will **create the new instance first**, then destroy the old one — ensuring zero downtime during replacement. Without this, it would destroy first and then create, causing downtime.

### The three lifecycle arguments

| Argument | What it does | When to use |
|---|---|---|
| `create_before_destroy` | Creates the replacement resource before destroying the old one | EC2 instances, load balancer targets — anywhere you need zero-downtime replacements |
| `prevent_destroy` | Terraform throws an error if you try to destroy this resource | Production databases, S3 buckets with critical data — a safety net against accidental `terraform destroy` |
| `ignore_changes` | Tells Terraform to ignore diffs for specific attributes | When another system (like an auto-scaler or config management tool) manages certain attributes — prevents Terraform from reverting those changes |

### Destroying everything

```bash
terraform destroy
# Type 'yes'
```

**Destroy order (reverse of creation):**
1. `aws_instance.main` and `aws_s3_bucket.app_logs`
2. `aws_security_group.web_sg`
3. `aws_route_table_association.public_assoc`
4. `aws_route_table.public_rt`
5. `aws_subnet.public` and `aws_internet_gateway.igw`
6. `aws_vpc.main` (last — everything else was inside it)

Terraform always destroys in **reverse dependency order** — the opposite of creation. Verified in AWS console — all resources gone ✅

---

## Implicit vs Explicit Dependencies — Summary

| Type | How it works | Example |
|---|---|---|
| **Implicit** | Terraform detects it automatically from attribute references | `vpc_id = aws_vpc.main.id` |
| **Explicit** | You declare it manually using `depends_on` | When no attribute reference exists but ordering still matters |

Implicit dependencies are preferred — they are self-documenting and always accurate. Use `depends_on` only when Terraform genuinely cannot detect the relationship.

---

## Complete File Structure

```
terraform-aws-infra/
├── providers.tf          # terraform block + provider config
├── main.tf               # all resources
├── .terraform/           # downloaded provider plugins (gitignore)
├── .terraform.lock.hcl   # provider version lock (commit this)
├── terraform.tfstate     # state file (gitignore)
└── graph.png             # dependency graph visualization
```

## `.gitignore` for this project

```gitignore
*.tfstate
*.tfstate.backup
.terraform/
graph.png
```

---

## Key Takeaways

1. **Provider version pinning** — `~> 5.0` allows safe minor updates while blocking breaking major version changes
2. **Implicit dependencies** — Terraform auto-detects creation order from `resource_type.name.attribute` references
3. **Explicit dependencies** — use `depends_on` when ordering matters but no attribute reference exists
4. **`terraform graph`** — visualizes the entire dependency tree in DOT format
5. **Lifecycle rules** — `create_before_destroy`, `prevent_destroy`, and `ignore_changes` give fine-grained control over resource behavior
6. **Destroy order** — always reverse of creation order, respecting all dependencies

---

## Screenshots

> 📁 All screenshots are stored in the `screenshots/` folder.

| # | Description | File |
|---|---|---|
| 1 | `terraform init` output showing provider version installed | `screenshots/01-terraform-init.png` |
| 2 | `.terraform.lock.hcl` contents | `screenshots/02-lock-file.png` |
| 3 | `terraform plan` showing 5 resources for VPC stack | `screenshots/03-plan-vpc-stack.png` |
| 4 | `terraform apply` creating all 5 VPC resources | `screenshots/04-apply-vpc.png` |
| 5 | AWS VPC console showing VPC created | `screenshots/05-vpc-console.png` |
| 6 | AWS console showing subnet, IGW, and route table | `screenshots/06-networking-console.png` |
| 7 | `terraform apply` adding security group and EC2 | `screenshots/07-apply-sg-ec2.png` |
| 8 | EC2 instance running with public IP in AWS console | `screenshots/08-ec2-console.png` |
| 9 | Security group rules in AWS console | `screenshots/09-sg-rules.png` |
| 10 | `terraform graph` DOT output or graph.png visualization | `screenshots/10-dependency-graph.png` |
| 11 | `terraform plan` showing `create_before_destroy` behavior | `screenshots/11-lifecycle-plan.png` |
| 12 | `terraform destroy` completing in reverse dependency order | `screenshots/12-terraform-destroy.png` |
| 13 | AWS console confirming all resources deleted | `screenshots/13-console-empty.png` |

---

## References

- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Dependency Docs](https://developer.hashicorp.com/terraform/language/meta-arguments/depends_on)
- [Terraform Lifecycle Docs](https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle)
- [90DaysOfDevOps Challenge](https://github.com/itzmayank01/90DaysOfDevOps)

---

*Day 62 of #90DaysOfDevOps | #TerraWeek | #DevOpsKaJosh | #TrainWithShubham*
