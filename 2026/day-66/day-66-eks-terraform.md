# Day 66 — Provision an EKS Cluster with Terraform Modules

## Overview

During Kubernetes week I set up clusters manually with kind and minikube. Today I provisioned one the DevOps way — fully automated, repeatable, and destroyable with a single command. Using **Terraform registry modules** I created a complete AWS EKS cluster with a managed node group, connected kubectl, deployed Nginx with a LoadBalancer, and tore everything down cleanly. This is exactly what infrastructure teams do every day in production.

---

## Task 1: Project Setup

### File structure

```
terraform-eks/
├── providers.tf        # Provider and backend config
├── vpc.tf              # VPC module call
├── eks.tf              # EKS module call
├── variables.tf        # All input variables
├── outputs.tf          # Cluster outputs
└── terraform.tfvars    # Variable values
```

### `providers.tf`

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.region
}
```

### `variables.tf`

```hcl
variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "cluster_name" {
  type    = string
  default = "terraweek-eks"
}

variable "cluster_version" {
  type    = string
  default = "1.31"
}

variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "node_desired_count" {
  type    = number
  default = 2
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}
```

### `terraform.tfvars`

```hcl
region             = "ap-south-1"
cluster_name       = "terraweek-eks"
cluster_version    = "1.31"
node_instance_type = "t3.medium"
node_desired_count = 2
vpc_cidr           = "10.0.0.0/16"
```

---

## Task 2: Creating the VPC with a Registry Module

EKS requires a specific VPC layout — public subnets for load balancers and private subnets for worker nodes, spread across multiple availability zones.

### `vpc.tf`

```hcl
data "aws_availability_zones" "available" {}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true       # one NAT to save cost in dev
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

  tags = {
    Environment = "dev"
    Project     = "TerraWeek"
    ManagedBy   = "Terraform"
  }
}
```

```bash
terraform init
terraform plan
# Plan: 23 to add, 0 to change, 0 to destroy
```

### Why does EKS need both public and private subnets?

**Private subnets** host the worker nodes (EC2 instances). Nodes should never be directly exposed to the internet — they communicate outbound through the NAT Gateway for pulling images and updates, but have no inbound public access.

**Public subnets** host the AWS Load Balancers that Services of type `LoadBalancer` create. The load balancer sits in the public subnet and proxies traffic to pods running on private nodes.

### What do the subnet tags do?

The Kubernetes AWS cloud controller uses these tags to automatically find the right subnets when creating load balancers:

- `kubernetes.io/role/elb = 1` on public subnets → tells AWS LB controller to use this subnet for **external** (internet-facing) load balancers
- `kubernetes.io/role/internal-elb = 1` on private subnets → used for **internal** load balancers (private access only)

Without these tags, `kubectl expose --type=LoadBalancer` would fail to find subnets to place the load balancer in.

---

## Task 3: Creating the EKS Cluster with Registry Module

### `eks.tf`

```hcl
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  eks_managed_node_groups = {
    terraweek_nodes = {
      ami_type       = "AL2_x86_64"
      instance_types = [var.node_instance_type]

      min_size     = 1
      max_size     = 3
      desired_size = var.node_desired_count
    }
  }

  tags = {
    Environment = "dev"
    Project     = "TerraWeek"
    ManagedBy   = "Terraform"
  }
}
```

```bash
terraform init      # Downloads EKS module and all its sub-dependencies
terraform plan      # Review carefully — 30+ resources
```

**Resources the EKS module creates automatically:**
- EKS control plane cluster
- IAM roles for the cluster and node group (with all required policies)
- Security groups for cluster and nodes
- EKS managed node group (EC2 Auto Scaling Group)
- CloudWatch log group for control plane logs
- OIDC provider for IRSA (IAM Roles for Service Accounts)
- Launch template for nodes

This is the power of Terraform modules — one `module` block replaces hundreds of lines of raw resource config.

---

## Task 4: Applying and Connecting kubectl

```bash
terraform apply
# Type 'yes'
# ... takes 10-15 minutes
# Apply complete! Resources: 56 added, 0 changed, 0 destroyed.
```

**Total resources created: 56**

### `outputs.tf`

```hcl
output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_region" {
  value = var.region
}
```

```bash
terraform output
# cluster_name    = "terraweek-eks"
# cluster_endpoint = "https://XXXXXXXXXXXX.gr7.ap-south-1.eks.amazonaws.com"
# cluster_region  = "ap-south-1"
```

### Connecting kubectl

```bash
aws eks update-kubeconfig --name terraweek-eks --region ap-south-1
# Added new context arn:aws:eks:ap-south-1:XXXXXXXXXXXX:cluster/terraweek-eks to ~/.kube/config
```

### Verifying the cluster

```bash
kubectl get nodes
```

**Output:**

```
NAME                                        STATUS   ROLES    AGE     VERSION
ip-10-0-3-xx.ap-south-1.compute.internal   Ready    <none>   3m      v1.31.x
ip-10-0-4-xx.ap-south-1.compute.internal   Ready    <none>   3m      v1.31.x
```

Both nodes in `Ready` state ✅

```bash
kubectl get pods -A
```

**Output:**

```
NAMESPACE     NAME                       READY   STATUS    RESTARTS
kube-system   aws-node-xxxxx             1/1     Running   0
kube-system   aws-node-yyyyy             1/1     Running   0
kube-system   coredns-xxxxx              1/1     Running   0
kube-system   coredns-yyyyy              1/1     Running   0
kube-system   kube-proxy-xxxxx           1/1     Running   0
kube-system   kube-proxy-yyyyy           1/1     Running   0
```

All kube-system pods running ✅

```bash
kubectl cluster-info
# Kubernetes control plane is running at https://XXXXXXXXXXXX.gr7.ap-south-1.eks.amazonaws.com
# CoreDNS is running at .../api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

---

## Task 5: Deploying a Workload on the Cluster

### `k8s/nginx-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-terraweek
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  type: LoadBalancer
  selector:
    app: nginx
  ports:
    - port: 80
      targetPort: 80
```

```bash
kubectl apply -f k8s/nginx-deployment.yaml
kubectl get svc nginx-service -w
```

**Output while waiting for LoadBalancer:**

```
NAME            TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
nginx-service   LoadBalancer   172.20.x.x     <pending>     80:31xxx/TCP   15s
nginx-service   LoadBalancer   172.20.x.x     a1b2c3d4xxx.ap-south-1.elb.amazonaws.com   80:31xxx/TCP   45s
```

### Verifying the full picture

```bash
kubectl get nodes
# 2 nodes Ready

kubectl get deployments
# nginx-terraweek   3/3   3   3

kubectl get pods
# nginx-terraweek-xxx   1/1   Running   0
# nginx-terraweek-yyy   1/1   Running   0
# nginx-terraweek-zzz   1/1   Running   0

kubectl get svc
# nginx-service   LoadBalancer   172.20.x.x   a1b2c3d4xxx.elb.amazonaws.com   80:31xxx/TCP
```

Accessed `http://a1b2c3d4xxx.ap-south-1.elb.amazonaws.com` in the browser → **Nginx welcome page loading** ✅

---

## Task 6: Destroying Everything

### Step 1 — Remove Kubernetes resources first

This is critical. If you run `terraform destroy` with the LoadBalancer Service still active, AWS won't delete the VPC because the ELB (created by Kubernetes, not Terraform) is still using subnets.

```bash
kubectl delete -f k8s/nginx-deployment.yaml
# deployment.apps "nginx-terraweek" deleted
# service "nginx-service" deleted
```

Wait for the ELB to fully disappear — check **EC2 → Load Balancers** in the AWS console. It takes 1-2 minutes.

### Step 2 — Destroy all Terraform resources

```bash
terraform destroy
# Type 'yes'
# ... takes 10-15 minutes
# Destroy complete! Resources: 56 destroyed.
```

### Step 3 — Verification in AWS console

| Resource | Status |
|---|---|
| EKS Clusters | ✅ Empty |
| EC2 Instances (node group) | ✅ Terminated |
| VPC (`terraweek-eks-vpc`) | ✅ Deleted |
| NAT Gateways | ✅ Deleted |
| Elastic IPs | ✅ Released |
| IAM Roles | ✅ Deleted |

AWS account is clean — no leftover resources and no ongoing charges ✅

---

## Reflection: EKS via Terraform vs Manual Cluster Setup (Day 50)

| | Manual (kind/minikube) | Terraform + EKS Modules |
|---|---|---|
| **Setup time** | 5 minutes | 15 minutes (AWS provisioning) |
| **Reproducibility** | Run a script again | `terraform apply` anywhere |
| **Production-ready** | No (local only) | Yes (managed control plane, multi-AZ) |
| **Networking** | Simulated | Real VPC, subnets, NAT, security groups |
| **Scaling** | Manual | Managed node groups with auto-scaling |
| **Teardown** | `kind delete cluster` | `terraform destroy` (removes everything) |
| **Cost** | Free | ~$0.10/hr (EKS) + EC2 + NAT |
| **Use case** | Local development, learning | Staging, production |

The manual approach is great for learning Kubernetes concepts. But for anything real — you use Terraform. The module abstracts away 500+ lines of raw resource config into a clean, versioned, reusable block. Any engineer on the team can clone the repo and spin up an identical cluster in 15 minutes.

---

## Key Takeaways

1. **Terraform modules** compress massive infrastructure into a few clean blocks — the EKS module alone manages IAM roles, security groups, node groups, and OIDC automatically
2. **Always delete Kubernetes LoadBalancer Services before `terraform destroy`** — ELBs created by Kubernetes are invisible to Terraform and will block VPC deletion
3. **Subnet tags are mandatory for EKS** — without `kubernetes.io/role/elb` tags, load balancers can't find their subnets
4. **Private subnets for nodes, public subnets for load balancers** — this separation is a security best practice
5. **`aws eks update-kubeconfig`** is the bridge between Terraform output and kubectl access
6. **NAT Gateway costs money** — always destroy when done with dev/learning clusters

---

## Screenshots

> 📁 All screenshots are stored in the `screenshots/` folder.

| # | Description | File |
|---|---|---|
| 1 | `terraform init` downloading EKS and VPC modules | `screenshots/01-terraform-init.png` |
| 2 | `terraform plan` showing 30+ resources | `screenshots/02-terraform-plan.png` |
| 3 | `terraform apply` completing — total resources created | `screenshots/03-terraform-apply-complete.png` |
| 4 | `kubectl get nodes` showing 2 nodes in Ready state | `screenshots/04-kubectl-get-nodes.png` |
| 5 | `kubectl get pods -A` showing kube-system pods running | `screenshots/05-kube-system-pods.png` |
| 6 | `kubectl cluster-info` output | `screenshots/06-cluster-info.png` |
| 7 | `kubectl apply` for nginx deployment and service | `screenshots/07-nginx-deployed.png` |
| 8 | `kubectl get svc -w` showing LoadBalancer getting external IP | `screenshots/08-loadbalancer-ip.png` |
| 9 | Nginx welcome page accessed via LoadBalancer URL | `screenshots/09-nginx-browser.png` |
| 10 | `kubectl get nodes/deployments/pods/svc` full picture | `screenshots/10-full-picture.png` |
| 11 | `terraform destroy` completing — 56 resources destroyed | `screenshots/11-terraform-destroy.png` |
| 12 | AWS console confirming EKS cluster deleted | `screenshots/12-aws-eks-empty.png` |
| 13 | AWS console confirming VPC deleted | `screenshots/13-aws-vpc-empty.png` |

---

## References

- [Terraform EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- [Terraform VPC Module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html)
- [90DaysOfDevOps Challenge](https://github.com/itzmayank01/90DaysOfDevOps)

---

*Day 66 of #90DaysOfDevOps | #TerraWeek | #DevOpsKaJosh | #TrainWithShubham*
