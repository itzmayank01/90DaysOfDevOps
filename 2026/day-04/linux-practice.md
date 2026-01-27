Day 04 – Linux Practice: Processes and Services



Today’s task focuses on practicing Linux fundamentals using real commands.

The goal was to understand how to inspect running processes, systemd services,

and system logs, and to follow a basic troubleshooting flow.



This practice was performed on an Ubuntu Linux environment.



---



Notes – Page 1

!\[Day 04 Linux Practice Notes Page 1](images/day04-linux-practice-1.jpg)



\### Notes – Page 2

!\[Day 04 Linux Practice Notes Page 2](images/day04-linux-practice-2.jpg)



\## Process Checks



\### 1. ps aux

\- Used to display all running processes on the system.

\- Helps identify high CPU or memory-consuming processes.



\### 2. top

\- Used to monitor live system performance.

\- Shows CPU usage, memory usage, and load average in real time.



\### 3. pgrep ssh

\- Used to check whether the SSH process is running.

\- Returns the PID of the ssh process if active.



---



\## Service Checks



\### 4. systemctl status ssh

\- Used to check the current status of the SSH service.

\- Shows whether the service is active or inactive, start time, and PID.



\### 5. systemctl list-units --type=service

\- Lists all active services managed by systemd.

\- Helps understand which background services are running.



\### 6. systemctl is-active ssh

\- Quickly checks whether the SSH service is active or inactive.

\- Useful for scripting and quick health checks.



---



\## Log Checks



\### 7. journalctl -u ssh

\- Displays logs related to the SSH service.

\- Useful for debugging login issues and identifying failed attempts.



\### 8. tail -n 50 /var/log/syslog

\- Shows the last 50 lines of system logs.

\- Helps check recent system activity and spot errors.



