# Day 58 — Metrics Server and Horizontal Pod Autoscaler (HPA)

## Overview

Yesterday I set resource requests and limits. Today I put them to work. I installed the **Metrics Server** so Kubernetes can see actual resource usage in real time, then configured a **Horizontal Pod Autoscaler** that automatically scales pods up under load and back down when traffic drops — exactly how production systems handle variable traffic.

---

## Task 1: Installing the Metrics Server

### Checking if it is already running

```bash
kubectl get pods -n kube-system | grep metrics-server
```

If nothing is returned, it is not installed. Install it based on your cluster type:

**Minikube:**

```bash
minikube addons enable metrics-server
```

**Kind / kubeadm (with insecure TLS flag for local clusters):**

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# For local clusters that need the insecure TLS flag
kubectl patch deployment metrics-server -n kube-system \
  --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

> ⚠️ `--kubelet-insecure-tls` is only for local learning clusters. Never use this in production.

Wait 60 seconds for Metrics Server to collect its first data points, then verify:

```bash
kubectl top nodes
```

**Output:**

```
NAME       CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
minikube   210m         5%     1024Mi          26%
```

```bash
kubectl top pods -A
```

**Output:**

```
NAMESPACE     NAME                               CPU(cores)   MEMORY(bytes)
kube-system   coredns-xxx                        3m           12Mi
kube-system   etcd-minikube                      18m          45Mi
kube-system   kube-apiserver-minikube            42m          210Mi
kube-system   metrics-server-xxx                 4m           15Mi
```

Metrics Server is installed and returning data ✅

---

## Task 2: Exploring `kubectl top`

```bash
kubectl top nodes
kubectl top pods -A
kubectl top pods -A --sort-by=cpu
```

### `kubectl top` vs requests/limits

| | `kubectl top` | `kubectl describe pod` |
|---|---|---|
| **Shows** | Actual real-time usage | Configured requests and limits |
| **Source** | Metrics Server (polls kubelets every 15s) | Pod spec (static config) |
| **Use for** | Observing what's happening now | Understanding scheduling and enforcement |

A pod might have `requests.cpu: 500m` but only be using `10m` in reality — `kubectl top` shows the truth, not the reservation.

**Most CPU-intensive pod:** `kube-apiserver-minikube` at `42m` in my cluster (the API server does the most work in a single-node setup).

---

## Task 3: Creating a Deployment with CPU Requests

HPA calculates utilization as a **percentage of requests** — without `resources.requests.cpu` set, HPA has no baseline to compare against and shows `<unknown>`.

### Deployment manifest

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: php-apache
spec:
  replicas: 1
  selector:
    matchLabels:
      app: php-apache
  template:
    metadata:
      labels:
        app: php-apache
    spec:
      containers:
        - name: php-apache
          image: registry.k8s.io/hpa-example
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: "200m"
            limits:
              cpu: "500m"
```

```bash
kubectl apply -f php-apache.yaml
kubectl expose deployment php-apache --port=80
kubectl top pod -l app=php-apache
```

**Output:**

```
NAME                          CPU(cores)   MEMORY(bytes)
php-apache-xxx                1m           10Mi
```

Current CPU usage at idle: `1m` — well below the `200m` request. ✅

---

## Task 4: Creating an HPA (Imperative)

```bash
kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10
```

```bash
kubectl get hpa
```

**Output (initial — metrics not yet collected):**

```
NAME         REFERENCE               TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   <unknown>/50%   1         10        1          5s
```

Wait 30 seconds:

```bash
kubectl get hpa
```

**Output (after metrics arrive):**

```
NAME         REFERENCE               TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
php-apache   Deployment/php-apache   1%/50%    1         10        1          40s
```

`TARGETS` shows `1%/50%` — current usage is 1% of requests, target threshold is 50%. ✅

```bash
kubectl describe hpa php-apache
```

Key output:

```
Metrics:  ( current / target )
  resource cpu on pods  (as a percentage of request):  1% (2m) / 50%
Min replicas:  1
Max replicas:  10
```

---

## Task 5: Generating Load and Watching Autoscaling

### Starting the load generator

```bash
kubectl run load-generator \
  --image=busybox:1.36 \
  --restart=Never \
  -- /bin/sh -c "while true; do wget -q -O- http://php-apache; done"
```

### Watching HPA react

```bash
kubectl get hpa php-apache --watch
```

**Output over ~3 minutes:**

```
NAME         REFERENCE               TARGETS    MINPODS   MAXPODS   REPLICAS
php-apache   Deployment/php-apache   1%/50%     1         10        1
php-apache   Deployment/php-apache   68%/50%    1         10        1
php-apache   Deployment/php-apache   98%/50%    1         10        3
php-apache   Deployment/php-apache   112%/50%   1         10        5
php-apache   Deployment/php-apache   74%/50%    1         10        5
php-apache   Deployment/php-apache   52%/50%    1         10        5
php-apache   Deployment/php-apache   48%/50%    1         10        5
```

**HPA scaled to 5 replicas** under load ✅

### HPA scaling formula

```
desiredReplicas = ceil(currentReplicas × (currentUsage / targetUsage))
               = ceil(1 × (98% / 50%))
               = ceil(1.96)
               = 2   → then rounds up further as usage climbs
```

### Stopping the load

```bash
kubectl delete pod load-generator
```

Scale-down is deliberately slow — a **5-minute stabilization window** prevents flapping (scaling up then immediately back down). No need to wait for it during the lab.

---

## Task 6: Creating an HPA from YAML (Declarative — autoscaling/v2)

### Why `autoscaling/v2`?

| Feature | `autoscaling/v1` | `autoscaling/v2` |
|---|---|---|
| Metrics | CPU only | CPU + Memory + custom metrics |
| Behavior control | None | Fine-grained scale-up/down speed |
| Multiple metrics | No | Yes |
| Stabilization window | Fixed (5min) | Configurable |

### Deleting the imperative HPA

```bash
kubectl delete hpa php-apache
```

### HPA v2 manifest

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: php-apache
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: php-apache
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0       # scale up immediately, no waiting
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15               # can double replicas every 15s
    scaleDown:
      stabilizationWindowSeconds: 300     # wait 5 minutes before scaling down
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60              # reduce by max 50% per minute
```

```bash
kubectl apply -f hpa-v2.yaml
kubectl describe hpa php-apache
```

### What does the `behavior` section control?

The `behavior` block gives you fine-grained control over **how fast** HPA reacts:

- **`scaleUp.stabilizationWindowSeconds: 0`** — scale up instantly when CPU exceeds the target. No delay. Traffic spikes need immediate response.
- **`scaleDown.stabilizationWindowSeconds: 300`** — wait 5 minutes of sustained low CPU before scaling down. Prevents premature scale-down during brief traffic dips.
- **`policies`** — rate limits on how aggressively scaling happens. `100 Percent per 15s` means it can double replicas every 15 seconds during a spike. `50 Percent per 60s` means it reduces by at most 50% per minute during scale-down.

---

## Task 7: Clean Up

```bash
kubectl delete hpa php-apache
kubectl delete svc php-apache
kubectl delete deployment php-apache
kubectl delete pod load-generator --ignore-not-found
```

Metrics Server is left installed — it is useful for all future work.

---

## How HPA Works — End to End

```
Metrics Server
  └── polls kubelet every 15s for actual CPU/memory usage
        └── stores in memory (not etcd)

HPA Controller (runs in kube-controller-manager)
  └── checks Metrics Server every 15s
  └── calculates: desiredReplicas = ceil(current × currentUsage/targetUsage)
  └── if desired ≠ current → patches Deployment replicas

Deployment Controller
  └── sees replica count changed → creates or deletes Pods
```

---

## Key Takeaways

1. **Metrics Server is required for HPA** — it is the data source. Without it, `kubectl top` and HPA both fail.
2. **`resources.requests.cpu` is mandatory for HPA** — HPA measures utilization as a % of requests. No requests = `<unknown>` targets.
3. **Scale-up is fast, scale-down is slow** — the 5-minute stabilization window prevents thrashing.
4. **`autoscaling/v2` is the current standard** — supports memory, custom metrics, and configurable behavior.
5. **`kubectl top` shows actual usage**, not requests/limits — always check both when debugging.
6. **HPA works with Deployments, StatefulSets, and ReplicaSets** — not with DaemonSets (every node always gets one).

---

## Screenshots

> 📁 All screenshots are stored in the `screenshots/` folder.

| # | Description | File |
|---|---|---|
| 1 | `minikube addons enable metrics-server` output | `screenshots/01-metrics-server-install.png` |
| 2 | `kubectl top nodes` showing CPU and memory usage | `screenshots/02-top-nodes.png` |
| 3 | `kubectl top pods -A` showing all pod usage | `screenshots/03-top-pods.png` |
| 4 | `kubectl top pods -A --sort-by=cpu` output | `screenshots/04-top-pods-sorted.png` |
| 5 | `kubectl get hpa` showing `<unknown>` then `1%/50%` | `screenshots/05-hpa-targets.png` |
| 6 | `kubectl describe hpa` output | `screenshots/06-hpa-describe.png` |
| 7 | Load generator running and HPA watching CPU climb | `screenshots/07-load-generator.png` |
| 8 | `kubectl get hpa --watch` showing replicas scaling up | `screenshots/08-hpa-scaling-up.png` |
| 9 | `kubectl get pods` showing multiple replicas running | `screenshots/09-pods-scaled.png` |
| 10 | `kubectl apply` for HPA v2 YAML and describe output | `screenshots/10-hpa-v2.png` |

---

## References

- [Kubernetes HPA Docs](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Metrics Server GitHub](https://github.com/kubernetes-sigs/metrics-server)
- [autoscaling/v2 API Reference](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/horizontal-pod-autoscaler-v2/)
- [90DaysOfDevOps Challenge](https://github.com/itzmayank01/90DaysOfDevOps)

---

*Day 58 of #90DaysOfDevOps | #DevOpsKaJosh | #TrainWithShubham*
