\# Day 08 – Cloud Server Setup: Docker, Nginx \& Web Deployment



\## Commands Used

\- sudo apt update \&\& sudo apt upgrade -y

\- sudo apt install docker.io -y

\- sudo systemctl start docker

\- sudo systemctl enable docker

\- sudo apt install nginx -y

\- sudo systemctl start nginx

\- sudo systemctl enable nginx

\- sudo systemctl status nginx

\- sudo cat /var/log/nginx/access.log

\- sudo cat /var/log/nginx/error.log

\- scp -i day08-key.pem ubuntu@<instance-ip>:~/nginx-logs.txt .



\## Challenges Faced

\- Faced issues while downloading files from EC2 using SCP on Windows.

\- Resolved by running SCP from PowerShell instead of the EC2 terminal and verifying correct file paths.



\## What I Learned

\- How to launch and access an AWS EC2 instance using SSH

\- Installing and managing Docker and Nginx on a cloud server

\- Configuring AWS security groups for web access

\- Extracting and downloading server logs

\- Understanding real-world DevOps workflow



\## Why This Matters for DevOps

This task reflects real DevOps responsibilities such as cloud provisioning, remote server management, service deployment, security configuration, and log monitoring.



