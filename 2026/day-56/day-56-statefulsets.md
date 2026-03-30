# Day 56 — Kubernetes StatefulSets

## Overview

Deployments are perfect for stateless apps like web servers — pods are interchangeable and it doesn't matter which one handles a request. But databases are different. A MySQL replica needs a **stable identity**, a **predictable startup order**, and **its own dedicated storage**. Today I learned StatefulSets — the Kubernetes workload designed exactly for these requirements.

---

## Task 1: Understanding the Problem — Why Deployments Don't Work for Databases

### Creating a Deployment with 3 replicas

```bash
kubectl create deployment nginx-demo --image=nginx --replicas=3
kubectl get pods
```

**Output:**

```
NAME                          READY   STATUS    RESTARTS   AGE
nginx-demo-6d4f9b8c7-xk2pq   1/1     Running   0          10s
nginx-demo-6d4f9b8c7-mn7rt   1/1     Running   0          10s
nginx-demo-6d4f9b8c7-zq9lw   1/1     Running   0          10s
```

After deleting one pod, the replacement gets a completely different random name. The old identity is gone.

**Why is this a problem for databases?**
In a database cluster (e.g., MySQL Group Replication, PostgreSQL with Patroni, Kafka), each node has a **role** — primary or replica. Other nodes need to know the address of the primary to replicate from it. If the primary pod restarts and gets a new random name and IP, the entire cluster loses track of who to replicate from. The cluster breaks. Stable, predictable identity is not optional — it is a hard requirement.

```bash
kubectl delete deployment nginx-demo
```

---

### Deployment vs StatefulSet — Key Differences

| Feature | Deployment | StatefulSet |
|---|---|---|
| Pod names | Random (`app-xyz-abc`) | Stable, ordered (`app-0`, `app-1`, `app-2`) |
| Startup order | All at once, parallel | Ordered: pod-0 → pod-1 → pod-2 |
| Storage | Shared PVC across all pods | Each pod gets its **own** dedicated PVC |
| Network identity | No stable hostname | Stable DNS per pod via Headless Service |
| Use case | Web servers, APIs, stateless apps | Databases, message queues, distributed systems |

---

## Task 2: Creating a Headless Service

A **Headless Service** (`clusterIP: None`) does not load-balance traffic. Instead, it creates individual DNS `A` records for each pod — so you can resolve `web-0.nginx-headless.default.svc.cluster.local` directly. StatefulSets require this for stable network identity.

### Headless Service manifest

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-headless
  labels:
    app: web
spec:
  clusterIP: None
  selector:
    app: web
  ports:
    - port: 80
      name: web
```

```bash
kubectl apply -f headless-service.yaml
kubectl get svc nginx-headless
```

**Output:**

```
NAME              TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
nginx-headless    ClusterIP   None         <none>        80/TCP    5s
```

**CLUSTER-IP shows `None`** — confirming it is a Headless Service. No virtual IP, no load balancing — just DNS records per pod. ✅

---

## Task 3: Creating the StatefulSet

### StatefulSet manifest

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "nginx-headless"
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
              name: web
          volumeMounts:
            - name: web-data
              mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
    - metadata:
        name: web-data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 100Mi
```

```bash
kubectl apply -f statefulset.yaml
kubectl get pods -l app=web -w
```

**Observed ordered creation:**

```
NAME    READY   STATUS              RESTARTS   AGE
web-0   0/1     ContainerCreating   0          2s
web-0   1/1     Running             0          8s
web-1   0/1     ContainerCreating   0          9s
web-1   1/1     Running             0          15s
web-2   0/1     ContainerCreating   0          16s
web-2   1/1     Running             0          22s
```

`web-1` only started after `web-0` was fully `Ready`. `web-2` only started after `web-1` was `Ready`. This is **ordered, sequential startup** — critical for distributed systems where later nodes need earlier ones to be available first.

### Checking PVCs

```bash
kubectl get pvc
```

**Output:**

```
NAME             STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
web-data-web-0   Bound    pvc-a1b2c3d4-xxxx-xxxx-xxxx-xxxxxxxxxxxx   100Mi      RWO            standard       30s
web-data-web-1   Bound    pvc-b2c3d4e5-xxxx-xxxx-xxxx-xxxxxxxxxxxx   100Mi      RWO            standard       22s
web-data-web-2   Bound    pvc-c3d4e5f6-xxxx-xxxx-xxxx-xxxxxxxxxxxx   100Mi      RWO            standard       14s
```

**Pod names:** `web-0`, `web-1`, `web-2` — stable and predictable ✅
**PVC names:** `web-data-web-0`, `web-data-web-1`, `web-data-web-2` — follow the pattern `<template-name>-<pod-name>` ✅

Each pod has its **own** PVC. No sharing.

---

## Task 4: Stable Network Identity — DNS Resolution

Each StatefulSet pod gets a DNS name following this pattern:

```
<pod-name>.<service-name>.<namespace>.svc.cluster.local
```

So for our setup:
- `web-0.nginx-headless.default.svc.cluster.local`
- `web-1.nginx-headless.default.svc.cluster.local`
- `web-2.nginx-headless.default.svc.cluster.local`

### Testing DNS with a busybox pod

```bash
kubectl run dns-test --image=busybox:1.28 --rm -it --restart=Never -- sh
```

Inside the busybox shell:

```bash
nslookup web-0.nginx-headless.default.svc.cluster.local
nslookup web-1.nginx-headless.default.svc.cluster.local
nslookup web-2.nginx-headless.default.svc.cluster.local
```

**Output:**

```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      web-0.nginx-headless.default.svc.cluster.local
Address 1: 10.244.0.5 web-0.nginx-headless.default.svc.cluster.local
```

### Verifying against pod IPs

```bash
kubectl get pods -o wide
```

```
NAME    READY   STATUS    IP           NODE
web-0   1/1     Running   10.244.0.5   minikube
web-1   1/1     Running   10.244.0.6   minikube
web-2   1/1     Running   10.244.0.7   minikube
```

**DNS IPs match Pod IPs exactly** ✅ — `web-0` always resolves to `web-0`'s IP, even after restarts.

---

## Task 5: Stable Storage — Data Survives Pod Deletion

### Writing unique data to each pod

```bash
kubectl exec web-0 -- sh -c "echo 'Data from web-0' > /usr/share/nginx/html/index.html"
kubectl exec web-1 -- sh -c "echo 'Data from web-1' > /usr/share/nginx/html/index.html"
kubectl exec web-2 -- sh -c "echo 'Data from web-2' > /usr/share/nginx/html/index.html"
```

### Verifying data exists

```bash
kubectl exec web-0 -- cat /usr/share/nginx/html/index.html
# Data from web-0
```

### Deleting web-0 and waiting for recreation

```bash
kubectl delete pod web-0
kubectl get pods -w
# web-0 terminates and a new web-0 comes back (same name!)
```

### Checking data after recreation

```bash
kubectl exec web-0 -- cat /usr/share/nginx/html/index.html
# Data from web-0
```

**Data is identical after pod recreation** ✅ — The new `web-0` automatically reconnected to `web-data-web-0`, the same PVC as before. The data never left the volume.

---

## Task 6: Ordered Scaling

### Scaling up to 5 replicas

```bash
kubectl scale statefulset web --replicas=5
kubectl get pods -w
```

Pods create in strict order: `web-3` first, then `web-4` only after `web-3` is Ready.

### Scaling down to 3 replicas

```bash
kubectl scale statefulset web --replicas=3
kubectl get pods -w
```

Pods terminate in **reverse order**: `web-4` first, then `web-3`.

### Checking PVCs after scale down

```bash
kubectl get pvc
```

**Output:**

```
NAME             STATUS   CAPACITY
web-data-web-0   Bound    100Mi
web-data-web-1   Bound    100Mi
web-data-web-2   Bound    100Mi
web-data-web-3   Bound    100Mi
web-data-web-4   Bound    100Mi
```

**All 5 PVCs still exist after scaling down to 3 pods** ✅

Kubernetes intentionally keeps PVCs on scale-down — if you scale back up to 5, `web-3` and `web-4` will reconnect to their same PVCs with all data intact. This is a safety feature, not a bug.

---

## Task 7: Clean Up

```bash
# Delete StatefulSet and Service
kubectl delete statefulset web
kubectl delete svc nginx-headless

# Check PVCs
kubectl get pvc
```

**PVCs are still present after StatefulSet deletion** — they are NOT auto-deleted. This is intentional. Kubernetes protects your data even when the workload is gone.

```bash
# Manually delete all PVCs
kubectl delete pvc web-data-web-0 web-data-web-1 web-data-web-2 web-data-web-3 web-data-web-4
```

**Which was auto-deleted:** Nothing — StatefulSet deletion never auto-deletes PVCs.
**Which was retained:** All PVCs — they required manual deletion.

---

## How volumeClaimTemplates Work

`volumeClaimTemplates` is a special StatefulSet field that acts as a PVC factory. For each pod replica, Kubernetes automatically creates a dedicated PVC using the template. The naming follows:

```
<template-name>-<statefulset-name>-<ordinal>
```

So `web-data` template + `web` StatefulSet + ordinal `0` = `web-data-web-0`.

This is fundamentally different from a Deployment where all pods share the same PVC — here every pod owns its storage independently.

---

## Key Takeaways

1. **Use StatefulSets for databases, message queues, and distributed systems** — anything that needs stable identity or per-pod storage
2. **Headless Services are mandatory** — they create individual DNS entries per pod instead of a single load-balanced IP
3. **Ordered startup and termination** — pod-0 before pod-1 before pod-2, and reverse for shutdown
4. **PVCs are never auto-deleted** — scaling down or deleting the StatefulSet keeps PVCs for safety
5. **Each pod has its own PVC** via `volumeClaimTemplates` — not shared storage
6. **Stable DNS** (`web-0.svc.default.svc.cluster.local`) survives pod restarts, giving databases a reliable way to find each other

---

## Screenshots

> 📁 All screenshots are stored in the `screenshots/` folder.

| # | Description | File |
|---|---|---|
| 1 | Deployment pods showing random names | `screenshots/01-deployment-random-names.png` |
| 2 | Headless Service created with `CLUSTER-IP: None` | `screenshots/02-headless-service.png` |
| 3 | `kubectl get pods -w` showing ordered pod creation | `screenshots/03-ordered-pod-creation.png` |
| 4 | `kubectl get pvc` showing 3 individual PVCs | `screenshots/04-pvc-per-pod.png` |
| 5 | `nslookup web-0` DNS resolution output | `screenshots/05-dns-web0.png` |
| 6 | `kubectl get pods -o wide` showing pod IPs matching DNS | `screenshots/06-pod-ips.png` |
| 7 | Data written to each pod's index.html | `screenshots/07-data-written.png` |
| 8 | Data persisted after web-0 deletion and recreation | `screenshots/08-data-persisted.png` |
| 9 | `kubectl get pods -w` showing ordered scale-up to 5 | `screenshots/09-scale-up.png` |
| 10 | `kubectl get pods -w` showing reverse order scale-down | `screenshots/10-scale-down.png` |
| 11 | `kubectl get pvc` showing all 5 PVCs after scale-down to 3 | `screenshots/11-pvcs-after-scaledown.png` |
| 12 | PVCs still present after StatefulSet deletion | `screenshots/12-pvcs-after-sts-delete.png` |
| 13 | Final cleanup — all PVCs manually deleted | `screenshots/13-cleanup-complete.png` |

---

## References

- [Kubernetes StatefulSets Docs](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- [Headless Services](https://kubernetes.io/docs/concepts/services-networking/service/#headless-services)
- [volumeClaimTemplates](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#volume-claim-templates)
- [90DaysOfDevOps Challenge](https://github.com/itzmayank01/90DaysOfDevOps)

---

*Day 56 of #90DaysOfDevOps | #DevOpsKaJosh | #TrainWithShubham*
