\# Linux Troubleshooting Runbook – Day 05



\## Target Service / Process

Service: SSH  

Process: sshd (listener)  

PID: 1035  

Host: AWS EC2 – Ubuntu 22.04 LTS  



---



\## Environment Basics

Command: uname -a  

Observation: Confirms kernel version and architecture.



Command: cat /etc/os-release  

Observation: Verifies Ubuntu distribution and version.



---



\## Filesystem Sanity

Command: mkdir /tmp/runbook-demo  

Observation: Directory created successfully; filesystem writable.



Command: cp /etc/hosts /tmp/runbook-demo/hosts-copy \&\& ls -l /tmp/runbook-demo  

Observation: File copy succeeded; no permission or IO errors.



---



\## Snapshot: CPU \& Memory

Command: top  

Observation: Load average ~0.00; system healthy.



Command: ps -o pid,pcpu,pmem,comm -p 1035  

Observation: sshd using negligible CPU and memory.



Command: free -h  

Observation: Sufficient free RAM; no swap usage.



---



\## Snapshot: Disk \& IO

Command: df -h  

Observation: Root filesystem has sufficient free space.



Command: du -sh /var/log  

Observation: Log size within normal limits.



---



\## Snapshot: Network

Command: ss -tulpn | grep ssh  

Observation: SSH listening on port 22.



Command: curl -I http://localhost  

Observation: Connection refused as expected; no HTTP service running.



---



\## Logs Reviewed

Command: journalctl -u ssh -n 50  

Observation: No SSH errors found.



Command: tail -n 50 /var/log/auth.log  

Observation: No failed authentication attempts.



---



\## Quick Findings

SSH service healthy. No CPU, memory, disk, or network issues detected.



---



\## If This Worsens (Next Steps)

1\. Restart SSH service during maintenance window.

2\. Increase SSH log verbosity.

3\. Capture tcpdump or strace for deeper analysis.



---



\## Resources

man sshd  

man journalctl



