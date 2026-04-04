# Day 57 — Resource Requests, Limits, and Probes

## Overview

Pods were running but Kubernetes had no idea how much CPU or memory they needed — and no way to tell if they were actually healthy. Today I fixed both problems: **resource requests and limits** for smart scheduling and runtime enforcement, and **liveness, readiness, and startup probes** so Kubernetes can detect and recover from failures automatically.

---

## Task 1: Resource Requests and Limits

### Understanding the difference

| | Requests | Limits |
|---|---|---|
| **Purpose** | Scheduling guarantee | Runtime enforcement |
| **Used by** | Scheduler (for Pod placement) | Kubelet (at runtime) |
| **Meaning** | "I need at least this much" | "I must never exceed this much" |
| **CPU exceeded** | N/A — scheduler only | Throttled (not killed) |
| **Memory exceeded** | N/A — scheduler only | OOMKilled (process killed) |

### Pod manifest with requests and limits

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-demo
spec:
  containers:
    - name: app
      image: nginx
      resources:
        requests:
          cpu: "100m"
          memory: "128Mi"
        limits:
          cpu: "250m"
          memory: "256Mi"
```

```bash
kubectl apply -f resource-demo.yaml
kubectl describe pod resource-demo
```

**Relevant output from `kubectl describe pod`:**

```
Containers:
  app:
    Requests:
      cpu:     100m
      memory:  128Mi
    Limits:
      cpu:     250m
      memory:  256Mi
QoS Class: Burstable
```

**QoS Class is `Burstable`** because requests are set lower than limits.

### QoS Classes explained

| QoS Class | Condition | Eviction Priority |
|---|---|---|
| `Guaranteed` | Requests == Limits for all containers | Last to be evicted |
| `Burstable` | Requests < Limits (at least one container) | Middle priority |
| `BestEffort` | No requests or limits set at all | First to be evicted |

### CPU units

`100m` = 100 millicores = 0.1 CPU. `1000m` = 1 full CPU core. Use millicores for fine-grained control without decimals.

---

## Task 2: OOMKilled — Exceeding Memory Limits

### What happens when memory is exceeded?

CPU is **compressible** — if a container exceeds its CPU limit, it gets throttled (slowed down) but keeps running. Memory is **incompressible** — if a container exceeds its memory limit, the Linux kernel kills the process immediately. No warning, no grace period.

### Pod manifest using stress

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: memory-stress
spec:
  containers:
    - name: stress
      image: polinux/stress
      resources:
        limits:
          memory: "100Mi"
      command: ["stress"]
      args: ["--vm", "1", "--vm-bytes", "200M", "--vm-hang", "1"]
```

The container tries to allocate 200M but the limit is 100Mi — it gets killed immediately.

```bash
kubectl apply -f memory-stress.yaml
kubectl describe pod memory-stress
```

**Output:**

```
State:          Terminated
  Reason:       OOMKilled
  Exit Code:    137
Last State:     Terminated
  Reason:       OOMKilled
  Exit Code:    137
```

**Exit code 137 = 128 + 9 (SIGKILL)** — the kernel sent SIGKILL (signal 9) to the process. `128 + signal_number` is the standard Linux exit code formula for signal-terminated processes.

**OOMKilled** = Out Of Memory Killed. The container will restart (based on `restartPolicy`) and get killed again in a loop — this shows up as `CrashLoopBackOff` in `kubectl get pods`.

---

## Task 3: Pending Pod — Requesting Too Much

### Pod manifest with impossible requests

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: too-greedy
spec:
  containers:
    - name: app
      image: nginx
      resources:
        requests:
          cpu: "100"
          memory: "128Gi"
```

```bash
kubectl apply -f too-greedy.yaml
kubectl get pod too-greedy
```

**Output:**

```
NAME         READY   STATUS    RESTARTS   AGE
too-greedy   0/1     Pending   0          2m
```

The Pod stays `Pending` forever — no node in the cluster has 100 CPUs and 128Gi of memory free.

```bash
kubectl describe pod too-greedy
```

**Events section:**

```
Events:
  Type     Reason            Age   Message
  ----     ------            ----  -------
  Warning  FailedScheduling  2m    0/1 nodes are available: 1 Insufficient cpu, 1 Insufficient memory.
```

The scheduler tells you exactly why — `Insufficient cpu` and `Insufficient memory`. The Pod will sit in `Pending` until either a node with enough resources joins the cluster or the requests are reduced.

---

## Task 4: Liveness Probe

A **liveness probe** answers: *"Is this container still alive and functional?"* If the probe fails `failureThreshold` times consecutively, Kubernetes **restarts** the container. It detects deadlocks, infinite loops, or any stuck state where the process is running but no longer doing useful work.

### Pod manifest with liveness probe

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-demo
spec:
  containers:
    - name: app
      image: busybox
      command: ["/bin/sh", "-c"]
      args:
        - touch /tmp/healthy; sleep 30; rm -f /tmp/healthy; sleep 600
      livenessProbe:
        exec:
          command:
            - cat
            - /tmp/healthy
        initialDelaySeconds: 5
        periodSeconds: 5
        failureThreshold: 3
```

**Timeline:**
- Container starts → creates `/tmp/healthy`
- After 30 seconds → deletes `/tmp/healthy`
- Liveness probe runs every 5 seconds → starts failing
- After 3 failures (15 seconds) → Kubernetes restarts the container

```bash
kubectl apply -f liveness-demo.yaml
kubectl get pod liveness-demo -w
```

**Output:**

```
NAME             READY   STATUS    RESTARTS   AGE
liveness-demo    1/1     Running   0          35s
liveness-demo    1/1     Running   1          52s
liveness-demo    1/1     Running   2          1m44s
```

**Container restarted** — `RESTARTS` column increments each time the liveness probe fails 3 times. ✅

---

## Task 5: Readiness Probe

A **readiness probe** answers: *"Is this container ready to receive traffic?"* Failure does **not** restart the container — it removes the Pod from the Service's endpoint list so no traffic is routed to it. The container keeps running but is taken out of rotation until it recovers.

### Pod manifest with readiness probe

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: readiness-demo
  labels:
    app: readiness-demo
spec:
  containers:
    - name: nginx
      image: nginx
      readinessProbe:
        httpGet:
          path: /
          port: 80
        initialDelaySeconds: 5
        periodSeconds: 5
        failureThreshold: 3
```

```bash
kubectl apply -f readiness-demo.yaml
kubectl expose pod readiness-demo --port=80 --name=readiness-svc
kubectl get endpoints readiness-svc
```

**Output — Pod IP is listed (ready):**

```
NAME            ENDPOINTS         AGE
readiness-svc   10.244.0.8:80     10s
```

### Breaking the readiness probe

```bash
kubectl exec readiness-demo -- rm /usr/share/nginx/html/index.html
```

Wait 15 seconds for probe to fail 3 times:

```bash
kubectl get pod readiness-demo
# NAME              READY   STATUS    RESTARTS
# readiness-demo    0/1     Running   0    ← Running but NOT ready

kubectl get endpoints readiness-svc
# NAME            ENDPOINTS   AGE
# readiness-svc   <none>      30s  ← Pod removed from endpoints
```

**Container was NOT restarted** (`RESTARTS` stays at 0) ✅
Pod is `Running` but `0/1 READY` — traffic stops reaching it but the process keeps running, giving it a chance to recover without a full restart.

---

## Task 6: Startup Probe

A **startup probe** gives slow-starting containers extra time to initialize. While the startup probe is running, **liveness and readiness probes are completely disabled** — they don't kick in until startup succeeds. This prevents liveness from killing a container that is still legitimately starting up.

### Pod manifest with startup + liveness probe

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: startup-demo
spec:
  containers:
    - name: slow-app
      image: busybox
      command: ["/bin/sh", "-c"]
      args:
        - sleep 20 && touch /tmp/started && sleep 600
      startupProbe:
        exec:
          command:
            - cat
            - /tmp/started
        periodSeconds: 5
        failureThreshold: 12    # 5s × 12 = 60 second budget
      livenessProbe:
        exec:
          command:
            - cat
            - /tmp/started
        periodSeconds: 10
        failureThreshold: 3
```

The container sleeps for 20 seconds before creating `/tmp/started`. The startup probe checks every 5 seconds with a budget of 60 seconds (12 × 5). Liveness only activates after the startup probe passes.

**What if `failureThreshold` were 2 instead of 12?**
The budget would be only 10 seconds (2 × 5s). The container takes 20 seconds to start — the startup probe would exhaust its budget at 10 seconds, Kubernetes would kill the container, and it would restart in a `CrashLoopBackOff` loop. The app would never successfully start even though it's working correctly. This is why the startup probe needs a generous `failureThreshold` for slow-starting apps.

---

## Probe Types Reference

| Probe Type | How it checks | Best for |
|---|---|---|
| `exec` | Runs a command inside the container — success if exit code is 0 | File existence checks, custom scripts |
| `httpGet` | Makes an HTTP GET request — success if status code is 2xx or 3xx | Web servers, REST APIs |
| `tcpSocket` | Opens a TCP connection — success if connection is accepted | Databases, any TCP service |

---

## Liveness vs Readiness vs Startup — Summary

| | Liveness | Readiness | Startup |
|---|---|---|---|
| **Answers** | Is the container alive? | Is it ready for traffic? | Has it finished starting? |
| **On failure** | Restart the container | Remove from endpoints | Kill the container |
| **On success** | Keep running | Add to endpoints | Enable liveness + readiness |
| **Use case** | Detect deadlocks/hangs | Rolling deployments, maintenance | Slow-starting apps |

---

## Task 7: Clean Up

```bash
kubectl delete pod resource-demo memory-stress too-greedy liveness-demo readiness-demo startup-demo
kubectl delete svc readiness-svc
```

---

## Key Takeaways

1. **Requests = scheduling**, Limits = runtime enforcement — two separate concerns
2. **CPU is throttled** when over limit; **Memory is OOMKilled** — no second chances
3. **Exit code 137** always means OOMKilled (128 + SIGKILL)
4. **`Pending` forever** = scheduler can't find a node with enough resources — check events
5. **Liveness failure = restart**, readiness failure = removed from traffic, startup = blocks the other two
6. **Startup probe prevents liveness from killing slow-starting containers** — always use it for apps with long init times

---

## Screenshots

> 📁 All screenshots are stored in the `screenshots/` folder.

| # | Description | File |
|---|---|---|
| 1 | `kubectl describe pod` showing Requests, Limits, QoS Class: Burstable | `screenshots/01-qos-burstable.png` |
| 2 | OOMKilled pod showing Reason: OOMKilled and Exit Code: 137 | `screenshots/02-oomkilled.png` |
| 3 | `kubectl get pod` showing memory-stress in CrashLoopBackOff | `screenshots/03-crashloopbackoff.png` |
| 4 | `kubectl get pod` showing too-greedy stuck in Pending | `screenshots/04-pending-pod.png` |
| 5 | `kubectl describe pod` showing FailedScheduling event with reason | `screenshots/05-scheduler-event.png` |
| 6 | `kubectl get pod -w` showing liveness probe triggering restarts | `screenshots/06-liveness-restarts.png` |
| 7 | `kubectl get endpoints` showing Pod IP before readiness failure | `screenshots/07-endpoints-ready.png` |
| 8 | Pod showing 0/1 READY after readiness failure, RESTARTS still 0 | `screenshots/08-readiness-not-ready.png` |
| 9 | `kubectl get endpoints` showing empty after readiness failure | `screenshots/09-endpoints-empty.png` |
| 10 | Startup probe keeping container alive during 20s sleep | `screenshots/10-startup-probe.png` |

---

## References

- [Kubernetes Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [QoS Classes](https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/)
- [90DaysOfDevOps Challenge](https://github.com/itzmayank01/90DaysOfDevOps)

---

*Day 57 of #90DaysOfDevOps | #DevOpsKaJosh | #TrainWithShubham*
