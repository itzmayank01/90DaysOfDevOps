# Day 11 – File Ownership Challenge (chown & chgrp)
## Objective
Learn how Linux manages file ownership using users and groups and practice changing ownership using chown and chgrp commands.

---

## Task 1 – Understanding Ownership

Command:
ls -l

Format:
-rw-r--r-- 1 owner group size date filename

Example:
-rw-r--r-- 1 mayank mayank sample.txt

Difference:
Owner → person who created/controls file  
Group → team members who share access  

---

## Task 2 – Change Owner using chown

Commands used:
touch devops-file.txt
sudo useradd tokyo
sudo useradd berlin
sudo chown tokyo devops-file.txt
sudo chown berlin devops-file.txt
ls -l devops-file.txt

Before:
mayank mayank

After:
berlin mayank

---

## Task 3 – Change Group using chgrp

Commands used:
touch team-notes.txt
sudo groupadd heist-team
sudo chgrp heist-team team-notes.txt
ls -l team-notes.txt

Before:
mayank mayank

After:
mayank heist-team

---

## Task 4 – Change Owner and Group Together

Commands used:
sudo useradd professor
touch project-config.yaml
sudo chown professor:heist-team project-config.yaml

mkdir app-logs
sudo chown berlin:heist-team app-logs

Result:
project-config.yaml → professor:heist-team  
app-logs → berlin:heist-team  

---

## Task 5 – Recursive Ownership

Commands used:
mkdir -p heist-project/vault
mkdir -p heist-project/plans
touch heist-project/vault/gold.txt
touch heist-project/plans/strategy.conf

sudo groupadd planners
sudo chown -R professor:planners heist-project
ls -lR heist-project

Result:
All files and folders changed to:
professor planners

Explanation:
-R applies ownership to entire directory recursively.

---

## Task 6 – Practice Challenge

Commands used:
sudo useradd nairobi
sudo groupadd vault-team
sudo groupadd tech-team

mkdir bank-heist
touch bank-heist/access-codes.txt
touch bank-heist/blueprints.pdf
touch bank-heist/escape-plan.txt

sudo chown tokyo:vault-team bank-heist/access-codes.txt
sudo chown berlin:tech-team bank-heist/blueprints.pdf
sudo chown nairobi:vault-team bank-heist/escape-plan.txt

Verification:
ls -l bank-heist

Result:
access-codes.txt → tokyo:vault-team  
blueprints.pdf → berlin:tech-team  
escape-plan.txt → nairobi:vault-team  

---

## Commands Summary

ls -l
useradd
groupadd
chown
chgrp
chown -R

---

## What I Learned

1. Owner controls file permissions and modifications  
2. Group allows multiple users to share access  
3. chown changes owner, chgrp changes group  
4. Recursive ownership saves time for directories  
5. Ownership is important for security and DevOps deployments  

---

## Real DevOps Use Cases

• Application deployment permissions  
• Shared team directories  
• Log file access control  
• CI/CD artifact management  
• Container volume permissions  

---

## Status
Day 11 completed successfully ✅

