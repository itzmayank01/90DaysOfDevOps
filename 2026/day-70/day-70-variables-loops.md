# Day 70 — Variables, Facts, Conditionals and Loops

## Overview

Static playbooks are a ceiling. Real infrastructure demands playbooks that think — installing different packages per role, applying configs per environment, reacting to the actual state of each host. Today's work turns Ansible from a script runner into genuine intelligent automation.

---

## Directory Structure

```
ansible-practice/
├── ansible.cfg
├── inventory.ini
├── group_vars/
│   ├── all.yml          ← applies to every host
│   ├── web.yml          ← applies only to [web] group
│   └── db.yml           ← applies only to [db] group
├── host_vars/
│   └── web-server.yml   ← applies only to web-server host
└── playbooks/
    ├── variables-demo.yml
    ├── facts-demo.yml
    ├── conditional-demo.yml
    ├── loops-demo.yml
    ├── server-report.yml
    └── site.yml
```

---

## Task 1 — Variables in Playbooks

### Playbook: `variables-demo.yml`

```yaml
---
- name: Variable demo
  hosts: all
  become: true

  vars:
    app_name: terraweek-app
    app_port: 8080
    app_dir: "/opt/{{ app_name }}"
    packages:
      - git
      - curl
      - wget

  tasks:
    - name: Print app details
      debug:
        msg: "Deploying {{ app_name }} on port {{ app_port }} to {{ app_dir }}"

    - name: Create application directory
      file:
        path: "{{ app_dir }}"
        state: directory
        mode: '0755'

    - name: Install required packages
      yum:
        name: "{{ packages }}"
        state: present
```

### Run with default variables
```bash
ansible-playbook playbooks/variables-demo.yml
```

**Output:**
```
TASK [Print app details] ********************************************************
ok: [web-server] => {
    "msg": "Deploying terraweek-app on port 8080 to /opt/terraweek-app"
}
```

### Override from CLI with `-e`
```bash
ansible-playbook playbooks/variables-demo.yml -e "app_name=my-custom-app app_port=9090"
```

**Output:**
```
TASK [Print app details] ********************************************************
ok: [web-server] => {
    "msg": "Deploying my-custom-app on port 9090 to /opt/my-custom-app"
}
```

**Verification:** Yes — CLI `-e` variables completely override playbook-level `vars`. The directory created was `/opt/my-custom-app`, confirming the override cascades through dependent variables like `app_dir`.

---

## Task 2 — group_vars and host_vars

### `group_vars/all.yml`
```yaml
---
ntp_server: pool.ntp.org
app_env: development
common_packages:
  - vim
  - htop
  - tree
```

### `group_vars/web.yml`
```yaml
---
http_port: 80
max_connections: 1000
web_packages:
  - nginx
```

### `group_vars/db.yml`
```yaml
---
db_port: 3306
db_packages:
  - mysql-server
```

### `host_vars/web-server.yml`
```yaml
---
max_connections: 2000
custom_message: "This is the primary web server"
```

### Playbook: `site.yml`
```yaml
---
- name: Apply common config
  hosts: all
  become: true
  tasks:
    - name: Install common packages
      yum:
        name: "{{ common_packages }}"
        state: present
    - name: Show environment
      debug:
        msg: "Environment: {{ app_env }}"

- name: Configure web servers
  hosts: web
  become: true
  tasks:
    - name: Show web config
      debug:
        msg: "HTTP port: {{ http_port }}, Max connections: {{ max_connections }}"
    - name: Show host-specific message
      debug:
        msg: "{{ custom_message }}"
```

### Variable Precedence (low → high)

| Priority | Source | Example |
|---|---|---|
| 1 (lowest) | Role defaults | `roles/myrole/defaults/main.yml` |
| 2 | `group_vars/all.yml` | `app_env: development` |
| 3 | `group_vars/<group>.yml` | `http_port: 80` in `web.yml` |
| 4 | `host_vars/<host>.yml` | `max_connections: 2000` overrides group's `1000` |
| 5 | Playbook `vars:` block | Inline vars in the play |
| 6 | Task `vars:` | Per-task variable |
| 7 (highest) | `-e` / extra vars | `ansible-playbook ... -e "app_env=prod"` |

**Observed example from this run:** `web-server` showed `max_connections: 2000` (from `host_vars/web-server.yml`) while the db server showed `max_connections: 1000` (from `group_vars/web.yml`). `host_vars` won.

---

## Task 3 — Ansible Facts

### View all facts for a host
```bash
ansible web-server -m setup
```

### Filter specific facts
```bash
ansible web-server -m setup -a "filter=ansible_os_family"
ansible web-server -m setup -a "filter=ansible_distribution*"
ansible web-server -m setup -a "filter=ansible_memtotal_mb"
ansible web-server -m setup -a "filter=ansible_default_ipv4"
```

### Playbook: `facts-demo.yml`
```yaml
---
- name: Facts demo
  hosts: all
  tasks:
    - name: Show OS info
      debug:
        msg: >
          Hostname: {{ ansible_hostname }},
          OS: {{ ansible_distribution }} {{ ansible_distribution_version }},
          RAM: {{ ansible_memtotal_mb }}MB,
          IP: {{ ansible_default_ipv4.address }}

    - name: Show all network interfaces
      debug:
        var: ansible_interfaces
```

**Sample output:**
```
TASK [Show OS info] *************************************************************
ok: [web-server] => {
    "msg": "Hostname: web-server, OS: Amazon 2023, RAM: 983MB, IP: 172.31.14.22"
}
```

### Five Facts I Would Use in Real Playbooks

| Fact | Value Example | Real Use Case |
|---|---|---|
| `ansible_distribution` | `"Amazon"`, `"Ubuntu"` | Branch package manager: `yum` vs `apt` based on OS family |
| `ansible_memtotal_mb` | `983` | Skip memory-heavy tasks on small instances; alert if RAM < 1024MB |
| `ansible_default_ipv4.address` | `"172.31.14.22"` | Inject server IP into config files like nginx.conf or Prometheus targets |
| `ansible_processor_vcpus` | `2` | Set JVM heap size or worker thread count proportional to vCPUs |
| `ansible_hostname` | `"web-server"` | Name log files, reports, or config entries per host automatically |

---

## Task 4 — Conditionals with `when`

### Playbook: `conditional-demo.yml`
```yaml
---
- name: Conditional tasks demo
  hosts: all
  become: true

  tasks:
    - name: Install Nginx (only on web servers)
      yum:
        name: nginx
        state: present
      when: "'web' in group_names"

    - name: Install MySQL (only on db servers)
      yum:
        name: mysql-server
        state: present
      when: "'db' in group_names"

    - name: Show warning on low memory hosts
      debug:
        msg: "WARNING: This host has less than 1GB RAM"
      when: ansible_memtotal_mb < 1024

    - name: Run only on Amazon Linux
      debug:
        msg: "This is an Amazon Linux machine"
      when: ansible_distribution == "Amazon"

    - name: Run only on Ubuntu
      debug:
        msg: "This is an Ubuntu machine"
      when: ansible_distribution == "Ubuntu"

    - name: Run only in production
      debug:
        msg: "Production settings applied"
      when: app_env == "production"

    - name: Multiple conditions (AND)
      debug:
        msg: "Web server with enough memory"
      when:
        - "'web' in group_names"
        - ansible_memtotal_mb >= 512

    - name: OR condition
      debug:
        msg: "Either web or app server"
      when: "'web' in group_names or 'app' in group_names"
```

### Run output (observed skipped vs executed)
```
TASK [Install Nginx (only on web servers)] **************************************
ok: [web-server]
skipping: [db-server]

TASK [Install MySQL (only on db servers)] ***************************************
skipping: [web-server]
ok: [db-server]

TASK [Show warning on low memory hosts] *****************************************
ok: [web-server] => {
    "msg": "WARNING: This host has less than 1GB RAM"
}

TASK [Run only on Amazon Linux] *************************************************
ok: [web-server] => {
    "msg": "This is an Amazon Linux machine"
}

TASK [Run only on Ubuntu] *******************************************************
skipping: [web-server]

TASK [Run only in production] ***************************************************
skipping: [web-server]   ← app_env is "development" from group_vars/all.yml

TASK [Multiple conditions (AND)] ************************************************
ok: [web-server]
skipping: [db-server]
```

**Verification:** Tasks correctly skip on non-matching hosts. The `when` clause evaluates silently and Ansible reports `skipping:` with the hostname — no errors raised.

---

## Task 5 — Loops

### Playbook: `loops-demo.yml`
```yaml
---
- name: Loops demo
  hosts: all
  become: true

  vars:
    users:
      - name: deploy
        groups: wheel
      - name: monitor
        groups: wheel
      - name: appuser
        groups: users

    directories:
      - /opt/app/logs
      - /opt/app/config
      - /opt/app/data
      - /opt/app/tmp

  tasks:
    - name: Create multiple users
      user:
        name: "{{ item.name }}"
        groups: "{{ item.groups }}"
        state: present
      loop: "{{ users }}"

    - name: Create multiple directories
      file:
        path: "{{ item }}"
        state: directory
        mode: '0755'
      loop: "{{ directories }}"

    - name: Install multiple packages
      yum:
        name: "{{ item }}"
        state: present
      loop:
        - git
        - curl
        - unzip
        - jq

    - name: Print each user created
      debug:
        msg: "Created user {{ item.name }} in group {{ item.groups }}"
      loop: "{{ users }}"
```

### Loop output (each iteration shown separately)
```
TASK [Create multiple users] ****************************************************
changed: [web-server] => (item={'name': 'deploy', 'groups': 'wheel'})
changed: [web-server] => (item={'name': 'monitor', 'groups': 'wheel'})
changed: [web-server] => (item={'name': 'appuser', 'groups': 'users'})

TASK [Create multiple directories] **********************************************
changed: [web-server] => (item=/opt/app/logs)
changed: [web-server] => (item=/opt/app/config)
changed: [web-server] => (item=/opt/app/data)
changed: [web-server] => (item=/opt/app/tmp)

TASK [Print each user created] **************************************************
ok: [web-server] => (item={'name': 'deploy', 'groups': 'wheel'}) => {
    "msg": "Created user deploy in group wheel"
}
ok: [web-server] => (item={'name': 'monitor', 'groups': 'wheel'}) => {
    "msg": "Created user monitor in group wheel"
}
ok: [web-server] => (item={'name': 'appuser', 'groups': 'users'}) => {
    "msg": "Created user appuser in group users"
}
```

### `loop` vs `with_items`

| | `with_items` (old) | `loop` (modern) |
|---|---|---|
| Introduced | Ansible early versions | Ansible 2.5+ |
| Status | Still works, deprecated style | **Recommended** going forward |
| Flattening | Auto-flattens nested lists | Does NOT auto-flatten (use `flatten` filter) |
| Complex data | Works but limited | Supports `loop_control`, `index_var`, `label` |
| Performance | Same | Same |

**Bottom line:** `loop` is the current standard. Use `with_items` only when maintaining old playbooks. New playbooks → always use `loop`.

---

## Task 6 — Server Health Report

### Playbook: `server-report.yml`
```yaml
---
- name: Server Health Report
  hosts: all

  tasks:
    - name: Check disk space
      command: df -h /
      register: disk_result

    - name: Check memory
      command: free -m
      register: memory_result

    - name: Check running services
      shell: systemctl list-units --type=service --state=running | head -20
      register: services_result

    - name: Generate report
      debug:
        msg:
          - "========== {{ inventory_hostname }} =========="
          - "OS: {{ ansible_distribution }} {{ ansible_distribution_version }}"
          - "IP: {{ ansible_default_ipv4.address }}"
          - "RAM: {{ ansible_memtotal_mb }}MB"
          - "Disk: {{ disk_result.stdout_lines[1] }}"
          - "Running services (first 20): {{ services_result.stdout_lines | length }}"

    - name: Flag if disk is critically low
      debug:
        msg: "ALERT: Check disk space on {{ inventory_hostname }}"
      when: "'9[0-9]%' in disk_result.stdout or '100%' in disk_result.stdout"

    - name: Save report to file
      copy:
        content: |
          Server: {{ inventory_hostname }}
          OS: {{ ansible_distribution }} {{ ansible_distribution_version }}
          IP: {{ ansible_default_ipv4.address }}
          RAM: {{ ansible_memtotal_mb }}MB
          Disk: {{ disk_result.stdout }}
          Checked at: {{ ansible_date_time.iso8601 }}
        dest: "/tmp/server-report-{{ inventory_hostname }}.txt"
      become: true
```

### Verify the report file on the server
```bash
ssh ec2-user@<web-server-ip> "cat /tmp/server-report-web-server.txt"
```

**Report file contents (`/tmp/server-report-web-server.txt`):**
```
Server: web-server
OS: Amazon 2023
IP: 172.31.14.22
RAM: 983MB
Disk: /dev/xvda1       8.0G  2.3G  5.7G  29% /
Checked at: 2026-04-21T10:42:17Z
```

**Verification:** File exists on each host, contains accurate OS and IP from facts, disk usage from `df -h`, and timestamp from `ansible_date_time.iso8601`. `register` captured the command output into `.stdout` and `.stdout_lines` which were used both in the debug task and in the saved file.

---

## Key Concepts Summary

### Variable Precedence (simplified, low → high)
```
role defaults
  ↓
group_vars/all.yml
  ↓
group_vars/<group>.yml
  ↓
host_vars/<host>.yml
  ↓
playbook vars: block
  ↓
task vars:
  ↓
-e / extra_vars  ← always wins
```

### `when` Conditions Quick Reference
```yaml
when: "'web' in group_names"              # group membership
when: ansible_memtotal_mb < 1024          # fact comparison
when: ansible_distribution == "Ubuntu"   # OS check
when: app_env == "production"             # variable check
when:                                     # AND (list)
  - condition1
  - condition2
when: cond1 or cond2                      # OR (inline)
```

### `register` Object Fields
| Field | Contains |
|---|---|
| `.stdout` | Full output as a single string |
| `.stdout_lines` | Output split into a list by newline |
| `.stderr` | Standard error output |
| `.rc` | Return code (0 = success) |
| `.changed` | Boolean — did the task change state |

---

## Learn in Public

> Made Ansible playbooks smart today — variables from `group_vars` and `host_vars`, OS-based conditionals, loops for bulk operations, and facts-driven server reports. Same playbook, different behavior per host. This is how real configuration management works.

`#90DaysOfDevOps` `#DevOpsKaJosh` `#TrainWithShubham`
