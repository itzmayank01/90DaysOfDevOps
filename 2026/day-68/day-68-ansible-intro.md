# Day 68 — Introduction to Ansible and Inventory Setup

## Overview

Terraform provisions infrastructure — VMs, networks, storage. But who installs packages, configures services, manages users, and keeps servers in the desired state after they exist? That is the job of a **configuration management tool**, and Ansible is the industry standard. Today I installed Ansible, provisioned EC2 instances, set up an inventory, and ran ad-hoc commands — all without installing a single agent on the target machines. Ansible only needs SSH.

---

## Task 1: Understanding Ansible

### What is Configuration Management and why do we need it?

Configuration management is the practice of maintaining servers in a known, consistent, desired state through code rather than manual steps. Without it, servers drift over time — one engineer installs a package, another changes a config file, someone updates a dependency and forgets to document it. Two servers that should be identical become subtly different. Bugs appear in production that can't be reproduced in staging.

Configuration management solves this by treating server state as code: version-controlled, peer-reviewed, and reproducible. Run the same playbook on 1 server or 1000 — the result is identical.

### Ansible vs Chef vs Puppet vs Salt

| Feature | Ansible | Chef | Puppet | Salt |
|---|---|---|---|---|
| **Architecture** | Agentless (SSH) | Agent required | Agent required | Agent (or agentless) |
| **Language** | YAML | Ruby DSL | Puppet DSL | YAML/Jinja2 |
| **Learning curve** | Low | High | High | Medium |
| **Push vs Pull** | Push | Pull | Pull | Both |
| **Setup complexity** | Minimal | High | High | Medium |
| **Best for** | Ad-hoc tasks, quick automation | Complex Ruby shops | Large enterprises | High-speed at scale |

Ansible wins on simplicity — no agents, no special language to learn, no server infrastructure to maintain. If you know YAML and SSH, you can start automating immediately.

### What does "agentless" mean?

Agentless means Ansible does **not** require any software to be installed on the managed nodes. It connects over standard SSH (Linux) or WinRM (Windows) that is already present on most servers. The control node pushes Python modules over SSH, executes them, and cleans them up — the managed node doesn't even know Ansible exists after the task is done.

---

### Ansible Architecture

```
┌─────────────────────────────────────────────────────┐
│                   CONTROL NODE                       │
│         (Your laptop / jump server)                  │
│                                                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │ Inventory│  │Playbooks │  │  ansible.cfg      │   │
│  │  .ini    │  │  .yml    │  │  (config file)    │   │
│  └──────────┘  └──────────┘  └──────────────────┘   │
└────────────────────────┬────────────────────────────┘
                         │ SSH
           ┌─────────────┼─────────────┐
           ▼             ▼             ▼
   ┌──────────────┐ ┌──────────┐ ┌──────────┐
   │  Web Server  │ │  App     │ │    DB    │
   │  (Managed    │ │  Server  │ │  Server  │
   │   Node 1)    │ │  Node 2  │ │  Node 3  │
   └──────────────┘ └──────────┘ └──────────┘
   No agent needed — SSH only
```

| Component | Role |
|---|---|
| **Control Node** | The machine where Ansible is installed and run — your laptop or a jump server |
| **Managed Nodes** | The servers Ansible configures — EC2 instances, VMs, etc. |
| **Inventory** | A file listing all managed nodes, grouped by role |
| **Modules** | Units of work Ansible executes — `apt`, `yum`, `copy`, `service`, `file` |
| **Playbooks** | YAML files defining what tasks to run on which hosts |

---

## Task 2: Lab Environment Setup (Terraform)

I used Terraform to provision 3 EC2 instances — putting TerraWeek skills to use.

### `main.tf` — EC2 instances for Ansible practice

```hcl
provider "aws" {
  region = "ap-south-1"
}

resource "aws_security_group" "ansible_sg" {
  name        = "ansible-practice-sg"
  description = "Allow SSH"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web" {
  ami                    = "ami-0f5ee92e2d63afc18"
  instance_type          = "t2.micro"
  key_name               = "my-key"
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]
  tags = { Name = "ansible-web" }
}

resource "aws_instance" "app" {
  ami                    = "ami-0f5ee92e2d63afc18"
  instance_type          = "t2.micro"
  key_name               = "my-key"
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]
  tags = { Name = "ansible-app" }
}

resource "aws_instance" "db" {
  ami                    = "ami-0f5ee92e2d63afc18"
  instance_type          = "t2.micro"
  key_name               = "my-key"
  vpc_security_group_ids = [aws_security_group.ansible_sg.id]
  tags = { Name = "ansible-db" }
}
```

```bash
terraform apply
# 3 EC2 instances created + security group
```

### Verifying SSH access to each instance

```bash
ssh -i ~/my-key.pem ec2-user@<web-public-ip>
ssh -i ~/my-key.pem ec2-user@<app-public-ip>
ssh -i ~/my-key.pem ec2-user@<db-public-ip>
```

All 3 instances accessible ✅

---

## Task 3: Installing Ansible

Ansible is installed **only on the control node** (my laptop / local machine). Managed nodes need nothing.

```bash
# macOS
brew install ansible

# Ubuntu/Debian
sudo apt update && sudo apt install ansible -y

# Amazon Linux / RHEL
pip3 install ansible
```

Verify installation:

```bash
ansible --version
```

**Output:**

```
ansible [core 2.x.x]
  config file = /etc/ansible/ansible.cfg
  configured module search path = ['/home/user/.ansible/plugins/modules']
  ansible python module location = /usr/lib/python3/dist-packages/ansible
  executable location = /usr/bin/ansible
  python version = 3.10.x
```

**Why is Ansible only needed on the control node?**
Ansible is a push-based tool. It runs locally, SSHs into each managed node, temporarily uploads a small Python module, executes it, collects the result, and removes the module. The managed node never has Ansible installed — it only needs Python (which comes pre-installed on most Linux AMIs) and SSH access.

---

## Task 4: Creating the Inventory File

```bash
mkdir ansible-practice && cd ansible-practice
```

### `inventory.ini`

```ini
[web]
web-server ansible_host=<WEB_PUBLIC_IP>

[app]
app-server ansible_host=<APP_PUBLIC_IP>

[db]
db-server ansible_host=<DB_PUBLIC_IP>

[all:vars]
ansible_user=ec2-user
ansible_ssh_private_key_file=~/my-key.pem
```

### Testing connectivity

```bash
ansible all -i inventory.ini -m ping
```

**Output:**

```
web-server | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
app-server | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
db-server | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

All 3 servers responding with green SUCCESS ✅

### Troubleshooting tips

```bash
# Fix key permissions if ping fails
chmod 400 ~/my-key.pem

# Check ansible_user — Amazon Linux uses ec2-user, Ubuntu uses ubuntu
# Verify SSH manually
ssh -i ~/my-key.pem ec2-user@<ip>
```

---

## Task 5: Running Ad-Hoc Commands

Ad-hoc commands are one-off tasks run directly from the terminal without a playbook — perfect for quick checks and immediate actions.

### 1. Check uptime on all servers

```bash
ansible all -i inventory.ini -m command -a "uptime"
```

**Output:**

```
web-server | CHANGED | rc=0 >>
 10:23:14 up 5 min,  1 user,  load average: 0.00, 0.01, 0.00
app-server | CHANGED | rc=0 >>
 10:23:14 up 5 min,  1 user,  load average: 0.00, 0.00, 0.00
db-server  | CHANGED | rc=0 >>
 10:23:15 up 5 min,  1 user,  load average: 0.00, 0.00, 0.00
```

### 2. Check free memory on web servers only

```bash
ansible web -i inventory.ini -m command -a "free -h"
```

**Output:**

```
web-server | CHANGED | rc=0 >>
              total  used  free  shared  buff/cache  available
Mem:           957M  135M  614M    456K        207M       821M
Swap:            0B    0B    0B
```

### 3. Check disk space on all servers

```bash
ansible all -i inventory.ini -m command -a "df -h"
```

**Output:**

```
web-server | CHANGED | rc=0 >>
Filesystem      Size  Used Avail Use% Mounted on
/dev/xvda1      8.0G  1.5G  6.5G  19% /
tmpfs           479M     0  479M   0% /dev/shm
...
```

### 4. Install git on web servers

```bash
ansible web -i inventory.ini -m yum -a "name=git state=present" --become
```

**Output:**

```
web-server | CHANGED => {
    "changed": true,
    "msg": "Installed: git-2.x.x"
}
```

**What does `--become` do?**
`--become` escalates privileges to root (equivalent to `sudo`). It is required for any task that needs elevated permissions — installing packages, managing services, editing system files, changing ownership. Without it, `yum install` would fail with a permission denied error since it requires root. In production, you can also specify `become_user` to escalate to a specific user other than root.

### 5. Copy a file to all servers

```bash
echo "Hello from Ansible" > hello.txt
ansible all -i inventory.ini -m copy -a "src=hello.txt dest=/tmp/hello.txt"
```

**Verify the file was copied:**

```bash
ansible all -i inventory.ini -m command -a "cat /tmp/hello.txt"
```

**Output:**

```
web-server | CHANGED | rc=0 >>
Hello from Ansible
app-server | CHANGED | rc=0 >>
Hello from Ansible
db-server  | CHANGED | rc=0 >>
Hello from Ansible
```

### `command` vs `shell` module

| | `command` module | `shell` module |
|---|---|---|
| **Executes** | Single command directly | Command through `/bin/sh` |
| **Pipes/redirects** | ❌ Not supported | ✅ Supported (`|`, `>`, `&&`) |
| **Variables** | ❌ No shell variables | ✅ `$HOME`, `$PATH` work |
| **Security** | Safer (no shell injection) | Less safe (shell expansion) |
| **Use when** | Simple commands | Need pipes, redirects, or shell features |

Example where you need `shell`:

```bash
# This requires shell module — command module can't handle pipes
ansible all -i inventory.ini -m shell -a "ps aux | grep nginx"
```

---

## Task 6: Inventory Groups and Patterns

### Adding group-of-groups to `inventory.ini`

```ini
[web]
web-server ansible_host=<WEB_IP>

[app]
app-server ansible_host=<APP_IP>

[db]
db-server ansible_host=<DB_IP>

[application:children]
web
app

[all_servers:children]
application
db

[all:vars]
ansible_user=ec2-user
ansible_ssh_private_key_file=~/my-key.pem
```

### Running against different groups

```bash
ansible application -i inventory.ini -m ping     # web + app only
ansible db -i inventory.ini -m ping               # db only
ansible all_servers -i inventory.ini -m ping      # everything
```

### Using patterns

```bash
ansible 'web:app' -i inventory.ini -m ping        # OR: web or app servers
ansible 'all:!db' -i inventory.ini -m ping        # NOT: all except db
```

### Creating `ansible.cfg` to simplify commands

```ini
[defaults]
inventory = inventory.ini
host_key_checking = False
remote_user = ec2-user
private_key_file = ~/my-key.pem
```

Now run without specifying inventory file every time:

```bash
ansible all -m ping
```

**Output:**

```
web-server | SUCCESS => { "ping": "pong" }
app-server | SUCCESS => { "ping": "pong" }
db-server  | SUCCESS => { "ping": "pong" }
```

`ansible all -m ping` works without `-i inventory.ini` ✅

**`ansible.cfg` lookup order:**
1. Current directory (`./ansible.cfg`) — checked first
2. User home (`~/.ansible.cfg`)
3. System-wide (`/etc/ansible/ansible.cfg`)

---

## Key Takeaways

1. **Ansible is agentless** — SSH is the only requirement on managed nodes, no software to install or maintain
2. **Inventory is the foundation** — groups and variables in `inventory.ini` define your entire infrastructure topology
3. **Ad-hoc commands for quick tasks** — use `-m command` or `-m shell` for one-off operations without writing a playbook
4. **`--become` = sudo** — always needed for package installs, service management, and system file changes
5. **`ansible.cfg` saves time** — set defaults once, stop repeating flags on every command
6. **`command` vs `shell`** — use `command` by default (safer), switch to `shell` only when you need pipes or shell features
7. **Patterns are powerful** — `all:!db`, `web:app` let you target exactly the right servers without editing inventory

---

## Screenshots

> 📁 All screenshots are stored in the `screenshots/` folder.

| # | Description | File |
|---|---|---|
| 1 | `ansible --version` output | `screenshots/01-ansible-version.png` |
| 2 | 3 EC2 instances running in AWS console (from Terraform) | `screenshots/02-ec2-instances.png` |
| 3 | `cat inventory.ini` showing grouped hosts | `screenshots/03-inventory.png` |
| 4 | `ansible all -m ping` showing all 3 green SUCCESS | `screenshots/04-ping-all-success.png` |
| 5 | `ansible all -m command -a "uptime"` output | `screenshots/05-uptime.png` |
| 6 | `ansible web -m command -a "free -h"` output | `screenshots/06-free-memory.png` |
| 7 | `ansible all -m command -a "df -h"` output | `screenshots/07-disk-space.png` |
| 8 | `ansible web -m yum -a "name=git state=present" --become` output | `screenshots/08-install-git.png` |
| 9 | Copy file and verify with `cat /tmp/hello.txt` on all servers | `screenshots/09-copy-verify.png` |
| 10 | `ansible all -m ping` working without `-i` flag (ansible.cfg) | `screenshots/10-ansible-cfg.png` |

---

## References

- [Ansible Official Documentation](https://docs.ansible.com/)
- [Ansible Inventory Guide](https://docs.ansible.com/ansible/latest/inventory_guide/index.html)
- [Ansible Ad-hoc Commands](https://docs.ansible.com/ansible/latest/command_guide/intro_adhoc.html)
- [90DaysOfDevOps Challenge](https://github.com/itzmayank01/90DaysOfDevOps)

---

*Day 68 of #90DaysOfDevOps | #DevOpsKaJosh | #TrainWithShubham*
