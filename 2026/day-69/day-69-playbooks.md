# Day 69 — Ansible Playbooks and Modules

## Overview

Ad-hoc commands are useful for quick checks, but real automation lives in **playbooks**. A playbook is a YAML file that describes the desired state of your servers — which packages to install, which services to run, which files to place where. Write it once, run it a hundred times, get the same result every time. Today I wrote multiple playbooks, learned the essential modules, and understood handlers, dry runs, and multi-play structure.

---

## Task 1: First Playbook — Install and Configure Nginx

### `install-nginx.yml`

```yaml
---
- name: Install and start Nginx on web servers
  hosts: web
  become: true

  tasks:
    - name: Install Nginx
      yum:
        name: nginx
        state: present

    - name: Start and enable Nginx
      service:
        name: nginx
        state: started
        enabled: true

    - name: Create a custom index page
      copy:
        content: "<h1>Deployed by Ansible - TerraWeek Server</h1>"
        dest: /usr/share/nginx/html/index.html
```

> Use `apt` instead of `yum` if your instances run Ubuntu.

### First run

```bash
ansible-playbook install-nginx.yml
```

**Output:**

```
PLAY [Install and start Nginx on web servers] **********************************

TASK [Gathering Facts] *********************************************************
ok: [web-server]

TASK [Install Nginx] ***********************************************************
changed: [web-server]

TASK [Start and enable Nginx] **************************************************
changed: [web-server]

TASK [Create a custom index page] **********************************************
changed: [web-server]

PLAY RECAP *********************************************************************
web-server : ok=4  changed=3  unreachable=0  failed=0
```

### Second run — Idempotency in action

```bash
ansible-playbook install-nginx.yml
```

**Output:**

```
TASK [Install Nginx] ***********************************************************
ok: [web-server]

TASK [Start and enable Nginx] **************************************************
ok: [web-server]

TASK [Create a custom index page] **********************************************
ok: [web-server]

PLAY RECAP *********************************************************************
web-server : ok=4  changed=0  unreachable=0  failed=0
```

**`changed=0` on the second run** ✅ — Ansible checked the current state, found everything already matches the desired state, and made zero changes. This is **idempotency** — the playbook is safe to run repeatedly without side effects.

### Verifying the custom page

```bash
curl http://<web-server-public-ip>
# <h1>Deployed by Ansible - TerraWeek Server</h1>
```

Custom Nginx page served correctly ✅

---

## Task 2: Playbook Structure — Annotated

```yaml
---                          # YAML document start — required for all playbooks

- name: Play name            # PLAY — a group of tasks targeting a set of hosts
  hosts: web                 # Which inventory group to run on (from inventory.ini)
  become: true               # Run all tasks as root (sudo) at the play level

  tasks:                     # Ordered list of tasks in this play

    - name: Task name        # TASK — one unit of work, maps to one module call
      module_name:           # MODULE — what Ansible actually does (yum, service, copy...)
        key: value           # Module arguments — specific to each module
```

### Answers to structure questions

**What is the difference between a play and a task?**
A **play** targets a group of hosts and contains a list of tasks. A **task** is a single action within that play — one module call. A playbook can have multiple plays; each play can have many tasks.

**Can you have multiple plays in one playbook?**
Yes. Multiple plays in one file let you configure different server groups with different tasks in a single `ansible-playbook` run. Web servers get Nginx, app servers get Node deps, DB servers get MySQL — all from one file.

**What does `become: true` do at play level vs task level?**
At the **play level**, it applies `sudo` to every task in the play. At the **task level**, it overrides only that specific task. You can set `become: false` on individual tasks to run them as the normal user even when the play uses `become: true`.

**What happens if a task fails — do remaining tasks still run?**
By default, Ansible stops the entire play for that host when a task fails. Other hosts that haven't reached the failure point continue. You can override this with `ignore_errors: true` on a task or `any_errors_fatal: false` at the play level.

---

## Task 3: Essential Modules Playbook

### `essential-modules.yml`

```yaml
---
- name: Practice essential Ansible modules
  hosts: all
  become: true

  tasks:

    # yum/apt — Install multiple packages at once
    - name: Install multiple packages
      yum:
        name:
          - git
          - curl
          - wget
          - tree
        state: present

    # service — Manage service state
    - name: Ensure Nginx is running and enabled on boot
      service:
        name: nginx
        state: started
        enabled: true

    # copy — Copy a file from control node to managed nodes
    - name: Copy config file to servers
      copy:
        src: files/app.conf
        dest: /etc/app.conf
        owner: root
        group: root
        mode: '0644'

    # file — Create directories and set permissions
    - name: Create application directory
      file:
        path: /opt/myapp
        state: directory
        owner: ec2-user
        mode: '0755'

    # command — Run a command (no shell features)
    - name: Check disk space
      command: df -h
      register: disk_output

    - name: Print disk space
      debug:
        var: disk_output.stdout_lines

    # shell — Run a command with shell features (pipes work here)
    - name: Count running processes
      shell: ps aux | wc -l
      register: process_count

    - name: Show process count
      debug:
        msg: "Total processes: {{ process_count.stdout }}"

    # lineinfile — Add or modify a single line in a file
    - name: Set timezone in environment
      lineinfile:
        path: /etc/environment
        line: 'TZ=Asia/Kolkata'
        create: true
```

### Supporting files

```bash
mkdir -p files
cat > files/app.conf << EOF
# App Configuration
APP_PORT=8080
APP_ENV=production
APP_LOG_LEVEL=info
EOF
```

```bash
ansible-playbook essential-modules.yml
```

### Module Reference Summary

| Module | Purpose | Key arguments |
|---|---|---|
| `yum` / `apt` | Install/remove packages | `name`, `state: present/absent/latest` |
| `service` | Manage system services | `name`, `state: started/stopped/restarted`, `enabled` |
| `copy` | Copy files from control node | `src`, `dest`, `owner`, `mode` |
| `file` | Create/delete files and directories | `path`, `state: directory/file/absent`, `mode` |
| `command` | Run a command (no shell expansion) | `cmd` or positional arg, `register` |
| `shell` | Run via `/bin/sh` (pipes work) | Same as `command` |
| `lineinfile` | Manage a single line in a file | `path`, `line`, `regexp`, `create` |
| `debug` | Print variables or messages | `var`, `msg` |

### `command` vs `shell` — When to use each

| | `command` | `shell` |
|---|---|---|
| **Execution** | Direct system call | Through `/bin/sh` |
| **Pipes (`\|`)** | ❌ Not supported | ✅ Works |
| **Redirects (`>`)** | ❌ Not supported | ✅ Works |
| **Shell variables** | ❌ `$HOME` won't expand | ✅ Works |
| **Security** | Safer — no injection risk | Less safe |
| **Use when** | Simple commands | Need pipes, redirects, or shell features |

**Rule of thumb:** Default to `command`. Switch to `shell` only when you genuinely need pipes or shell expansion. Using `shell` unnecessarily introduces injection risk and makes playbooks harder to predict.

---

## Task 4: Handlers — Restart Services Only When Needed

Handlers are special tasks that only run when **notified** by another task. If a config file doesn't change, the handler never runs — no unnecessary service restarts.

### `files/nginx.conf`

```nginx
events {
    worker_connections 1024;
}

http {
    server {
        listen 80;
        server_name _;

        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
}
```

### `nginx-config.yml`

```yaml
---
- name: Configure Nginx with a custom config
  hosts: web
  become: true

  tasks:
    - name: Install Nginx
      yum:
        name: nginx
        state: present

    - name: Deploy Nginx config
      copy:
        src: files/nginx.conf
        dest: /etc/nginx/nginx.conf
        owner: root
        mode: '0644'
      notify: Restart Nginx          # ← triggers handler ONLY if this task changes

    - name: Deploy custom index page
      copy:
        content: "<h1>Managed by Ansible</h1><p>Server: {{ inventory_hostname }}</p>"
        dest: /usr/share/nginx/html/index.html

    - name: Ensure Nginx is running
      service:
        name: nginx
        state: started
        enabled: true

  handlers:
    - name: Restart Nginx
      service:
        name: nginx
        state: restarted
```

### First run — handler triggers

```bash
ansible-playbook nginx-config.yml
```

**Output:**

```
TASK [Deploy Nginx config] *****************************************************
changed: [web-server]

RUNNING HANDLER [Restart Nginx] ************************************************
changed: [web-server]

PLAY RECAP *********************************************************************
web-server : ok=5  changed=3  unreachable=0  failed=0
```

Handler ran because the config file was new/changed ✅

### Second run — handler does NOT trigger

```bash
ansible-playbook nginx-config.yml
```

**Output:**

```
TASK [Deploy Nginx config] *****************************************************
ok: [web-server]

PLAY RECAP *********************************************************************
web-server : ok=4  changed=0  unreachable=0  failed=0
```

`RUNNING HANDLER` line is completely absent — the config file didn't change, so the handler was never notified ✅

**Key handler behaviors:**
- Handlers run **once at the end** of all tasks, even if notified multiple times during the play
- Handlers only run when at least one task that notified them actually made a change (`changed`, not `ok`)
- Multiple tasks can `notify` the same handler — it still only runs once

---

## Task 5: Dry Run, Diff, and Verbosity

### `--check` — Dry run

```bash
ansible-playbook install-nginx.yml --check
```

Shows what *would* change without touching any server. All tasks run in simulation mode — no actual changes applied. Essential before running on production.

### `--check --diff` — The most important combination

```bash
ansible-playbook nginx-config.yml --check --diff
```

**Output:**

```
TASK [Deploy Nginx config] *****************************************************
--- before: /etc/nginx/nginx.conf
+++ after: files/nginx.conf
@@ -1,5 +1,12 @@
+events {
+    worker_connections 1024;
+}
+
+http {
...

changed: [web-server]
```

**Why `--check --diff` is the most important flag combination for production:**
`--check` alone tells you *that* something will change. `--diff` shows you *exactly what* will change — like a `git diff` for your server's file system. Before touching a production server, you can review every line that will be modified, added, or removed. It prevents surprises and gives you the confidence to apply changes safely.

### Verbosity levels

```bash
ansible-playbook install-nginx.yml -v       # shows task results
ansible-playbook install-nginx.yml -vv      # shows task arguments and results
ansible-playbook install-nginx.yml -vvv     # shows SSH connection details
```

### Targeting and listing

```bash
# Only run on a specific host from the inventory group
ansible-playbook install-nginx.yml --limit web-server

# Preview which hosts would be affected
ansible-playbook install-nginx.yml --list-hosts

# Preview which tasks would run
ansible-playbook install-nginx.yml --list-tasks
```

---

## Task 6: Multiple Plays in One Playbook

### `multi-play.yml`

```yaml
---
- name: Configure web servers
  hosts: web
  become: true
  tasks:
    - name: Install Nginx
      yum:
        name: nginx
        state: present
    - name: Start Nginx
      service:
        name: nginx
        state: started
        enabled: true

- name: Configure app servers
  hosts: app
  become: true
  tasks:
    - name: Install Node.js build dependencies
      yum:
        name:
          - gcc
          - make
        state: present
    - name: Create app directory
      file:
        path: /opt/app
        state: directory
        mode: '0755'

- name: Configure database servers
  hosts: db
  become: true
  tasks:
    - name: Install MySQL client
      yum:
        name: mysql
        state: present
    - name: Create data directory
      file:
        path: /var/lib/appdata
        state: directory
        mode: '0700'
```

```bash
ansible-playbook multi-play.yml
```

**Output:**

```
PLAY [Configure web servers] ***************************************************
TASK [Install Nginx] ****** changed: [web-server]
TASK [Start Nginx] ******** changed: [web-server]

PLAY [Configure app servers] ***************************************************
TASK [Install gcc/make] **** changed: [app-server]
TASK [Create app dir] ****** changed: [app-server]

PLAY [Configure database servers] **********************************************
TASK [Install MySQL client] * changed: [db-server]
TASK [Create data dir] ****** changed: [db-server]

PLAY RECAP *********************************************************************
web-server : ok=3  changed=2
app-server : ok=3  changed=2
db-server  : ok=3  changed=2
```

**Nginx only installed on `web-server`** ✅
**MySQL only installed on `db-server`** ✅

Each play runs independently on its targeted group — tasks from one play never run on the wrong hosts.

---

## Playbook Flags Quick Reference

| Flag | Purpose |
|---|---|
| `--check` | Dry run — simulate without making changes |
| `--diff` | Show file diffs for changed content |
| `--check --diff` | Preview exactly what will change — use before production |
| `-v / -vv / -vvv` | Increase verbosity for debugging |
| `--limit <host>` | Run only on specific host(s) |
| `--list-hosts` | Show which hosts would be targeted |
| `--list-tasks` | Show which tasks would run |
| `--syntax-check` | Validate YAML syntax without connecting to servers |
| `--tags <tag>` | Run only tasks with specific tags |
| `--start-at-task` | Start execution from a specific task name |

---

## Key Takeaways

1. **Idempotency is the core principle** — run the same playbook 10 times, the result is always the same. `ok` means already correct, `changed` means Ansible fixed it.
2. **Handlers prevent unnecessary restarts** — a service only restarts when its config actually changes, not on every playbook run
3. **`register` + `debug`** — capture any command's output into a variable and print it, essential for auditing
4. **`--check --diff` before every production change** — see exactly what will change before it happens
5. **Multiple plays = one file, multiple server roles** — cleaner than separate playbooks for related infrastructure
6. **`command` vs `shell`** — use `command` by default, `shell` only when pipes or redirects are needed

---

## Screenshots

> 📁 All screenshots are stored in the `screenshots/` folder.

| # | Description | File |
|---|---|---|
| 1 | First `ansible-playbook install-nginx.yml` run showing `changed=3` | `screenshots/01-first-run-changed.png` |
| 2 | Second run showing `changed=0` — idempotency proof | `screenshots/02-second-run-ok.png` |
| 3 | `curl <web-ip>` showing custom Nginx page | `screenshots/03-nginx-custom-page.png` |
| 4 | `essential-modules.yml` run with debug output for disk and processes | `screenshots/04-essential-modules.png` |
| 5 | First `nginx-config.yml` run — handler triggered | `screenshots/05-handler-triggered.png` |
| 6 | Second `nginx-config.yml` run — handler NOT triggered | `screenshots/06-handler-not-triggered.png` |
| 7 | `--check --diff` output showing file diff | `screenshots/07-check-diff.png` |
| 8 | `--list-tasks` output | `screenshots/08-list-tasks.png` |
| 9 | `multi-play.yml` run showing separate plays per server group | `screenshots/09-multi-play.png` |
| 10 | Verification — Nginx on web only, MySQL on db only | `screenshots/10-role-verification.png` |

---

## References

- [Ansible Playbook Documentation](https://docs.ansible.com/ansible/latest/playbook_guide/index.html)
- [Ansible Module Index](https://docs.ansible.com/ansible/latest/collections/index_module.html)
- [Ansible Handlers](https://docs.ansible.com/ansible/latest/playbook_guide/playbooks_handlers.html)
- [90DaysOfDevOps Challenge](https://github.com/itzmayank01/90DaysOfDevOps)

---

*Day 69 of #90DaysOfDevOps | #DevOpsKaJosh | #TrainWithShubham*
