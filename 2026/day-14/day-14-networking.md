# Day 14 – Networking Fundamentals & Hands-on Checks

## 🔎 Target Used
trainwithshubham.com  
google.com  
Local DNS Service (Port 53)


# 🧠 Quick Concepts

### OSI vs TCP/IP
- OSI has 7 layers (Physical → Application)
- TCP/IP has 4 layers (Link, Internet, Transport, Application)

### Protocol Mapping
- IP → Internet Layer
- TCP/UDP → Transport Layer
- HTTP/HTTPS → Application Layer
- DNS → Application Layer (uses UDP/TCP at transport)

### Real Example
`curl https://google.com`  
Application (HTTP) → Transport (TCP) → Internet (IP)

---

# 🖥 Hands-on Commands & Observations

---

## 1️⃣ Identity Check

Command:
ip addr show
hostname -I


Observation:
- Local IP Address: `172.19.109.239`

📸 Screenshot:

![IP Address](Screenshot%202026-02-08%20233942.png)

---

## 2️⃣ Reachability Test

Command:


ping trainwithshubham.com


Observation:
- 0% packet loss
- Avg latency ≈ 73 ms
- Target resolved to AWS Global Accelerator (15.197.225.128)

📸 Screenshot:

![Ping Output](Screenshot%202026-02-08%20234005.png)

---

## 3️⃣ Traceroute Installation

Command:


sudo apt install traceroute


Observation:
- traceroute installed successfully

📸 Screenshot:

![Traceroute Install](Screenshot%202026-02-08%20234036.png)

---

## 4️⃣ Listening Ports Check

Command:


ss -tulpn


Observation:
- DNS service listening on port 53
- Multiple UDP & TCP sockets on 127.0.0.53

📸 Screenshot:

![SS Output](Screenshot%202026-02-08%20234105.png)

---

## 5️⃣ Name Resolution

Command:


nslookup trainwithshubham.com


Observation:
- Resolved IPs:
  - 15.197.225.128
  - 3.33.251.168

📸 Screenshot:

![NSLookup](Screenshot%202026-02-08%20234121.png)

---

## 6️⃣ HTTP Check

Command:


curl -I https://google.com


Observation:
- HTTP/2 204 response
- Server reachable
- HTTPS working properly

📸 Screenshot:

![Curl Output](Screenshot%202026-02-08%20234105.png)

---

## 7️⃣ Port Probe (Mini Task)

Identified listening port:
- DNS on 127.0.0.53:53

Test:


nc -zv 127.0.0.53 53


Result:
- Connection succeeded
- Service reachable

---

# 🧩 Reflection

### Fastest Signal When Something Breaks
`ping` gives quickest network reachability signal.

### If DNS Fails
Inspect:
- Application Layer (DNS service)
- Check `/etc/resolv.conf`
- Check port 53 listening

### If HTTP 500 Appears
- Application Layer issue
- Check web server logs
- Check backend service health

### Two Follow-up Checks in Real Incident
1. `ss -tulpn` to check listening ports
2. `curl -v` for detailed HTTP debugging

---

# 🚀 Learn in Public

Today I practiced core networking troubleshooting commands:
- ping
- traceroute
- ss
- nslookup
- curl

Interesting finding: trainwithshubham.com routes through AWS Global Accelerator.

#90DaysOfDevOps  
#DevOpsKaJosh  
#TrainWithShubham

✅ Final Steps

Now run:

git add 2026/day-14/day-14-networking.md
git commit -m "Day 14 - Networking fundamentals and hands-on checks"
git push origin master