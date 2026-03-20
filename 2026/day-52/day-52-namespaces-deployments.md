# Day 52 – Kubernetes Namespaces and Deployments

## What are Namespaces and Why Use Them?

Namespaces in Kubernetes are a way to divide a single cluster into multiple virtual clusters. They provide a mechanism for isolating groups of resources within a cluster.

**Why use namespaces?**
- **Environment separation** – Keep `dev`, `staging`, and `production` resources isolated within the same cluster.
- **Team isolation** – Different teams can work in their own namespaces without interfering with each other.
- **Resource management** – Apply resource quotas and limits per namespace.
- **Access control** – Apply RBAC policies scoped to specific namespaces.
- **Clarity** – Avoid naming collisions; two teams can both have an `nginx` deployment in different namespaces.

### Default Namespaces in Kubernetes

| Namespace | Purpose |
|---|---|
| `default` | Where resources go if no namespace is specified |
| `kube-system` | Kubernetes internal components (API server, scheduler, etc.) |
| `kube-public` | Publicly readable resources, accessible cluster-wide |
| `kube-node-lease` | Node heartbeat tracking for improved node failure detection |

---

## Task 1: Exploring Default Namespaces

```bash
kubectl get namespaces
```

Check pods running in `kube-system`:

```bash
kubectl get pods -n kube-system
```

These pods are the control plane components — the API server, scheduler, controller manager, CoreDNS, etcd, and kube-proxy. **Do not modify or delete them.**

---

## Task 2: Creating Custom Namespaces

### Imperative (CLI)

```bash
kubectl create namespace dev
kubectl create namespace staging
kubectl get namespaces
```

### Declarative (YAML)

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: production
```

```bash
kubectl apply -f namespace.yaml
```

### Running Pods in Specific Namespaces

```bash
kubectl run nginx-dev --image=nginx:latest -n dev
kubectl run nginx-staging --image=nginx:latest -n staging
```

### Listing Pods Across Namespaces

```bash
# Only shows pods in 'default' namespace
kubectl get pods

# Shows pods in all namespaces
kubectl get pods -A
```

> **Observation:** `kubectl get pods` only shows pods in the `default` namespace. The pods in `dev` and `staging` are only visible when using `-n <namespace>` or `-A`.

---

## Task 3: Your First Deployment

### nginx-deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: dev
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.24
        ports:
        - containerPort: 80
```

### Section-by-Section Explanation

| Field | Explanation |
|---|---|
| `apiVersion: apps/v1` | Deployments are part of the `apps` API group |
| `kind: Deployment` | Resource type — manages a set of replica Pods |
| `metadata.name` | Name of the Deployment |
| `metadata.namespace` | Namespace where this Deployment lives |
| `spec.replicas` | Number of identical Pod replicas to maintain |
| `spec.selector.matchLabels` | How the Deployment identifies which Pods it owns |
| `spec.template` | The Pod blueprint — the Deployment creates Pods using this |
| `spec.template.metadata.labels` | Must match `selector.matchLabels` exactly |
| `spec.template.spec.containers` | The containers to run in each Pod |

### Apply and Verify

```bash
kubectl apply -f nginx-deployment.yaml
kubectl get deployments -n dev
kubectl get pods -n dev
```

### Understanding Deployment Columns

| Column | Meaning |
|---|---|
| `READY` | Number of pods ready vs desired (e.g., `3/3`) |
| `UP-TO-DATE` | Pods updated to the latest desired spec |
| `AVAILABLE` | Pods available to serve traffic |

---

## Task 4: Self-Healing — Delete a Pod and Watch It Come Back

```bash
# List pods
kubectl get pods -n dev

# Delete one pod (replace with an actual pod name)
kubectl delete pod <pod-name> -n dev

# Immediately check again
kubectl get pods -n dev
```

> **Key Insight:** When you delete a Pod that belongs to a Deployment, the Deployment controller immediately detects the discrepancy (2 running vs 3 desired) and creates a brand new Pod. The replacement Pod gets a **new, different name** — it is not the same Pod brought back.

**Standalone Pod vs Deployment-managed Pod:**

| Scenario | What Happens on Deletion |
|---|---|
| Standalone Pod | Gone forever — nobody recreates it |
| Deployment-managed Pod | Automatically recreated by the Deployment controller |

---

## Task 5: Scaling a Deployment

### Imperative Scaling

```bash
# Scale up to 5 replicas
kubectl scale deployment nginx-deployment --replicas=5 -n dev
kubectl get pods -n dev

# Scale down to 2 replicas
kubectl scale deployment nginx-deployment --replicas=2 -n dev
kubectl get pods -n dev
```

### Declarative Scaling

Edit `nginx-deployment.yaml` — change `replicas: 3` to `replicas: 4` — then:

```bash
kubectl apply -f nginx-deployment.yaml
```

> **What happened when scaling down from 5 to 2?** Kubernetes immediately terminated 3 of the 5 running pods. The pods in `Terminating` state briefly appeared before disappearing, leaving exactly 2 pods running.

---

## Task 6: Rolling Updates and Rollbacks

### Trigger a Rolling Update

```bash
kubectl set image deployment/nginx-deployment nginx=nginx:1.25 -n dev
```

### Watch the Rollout

```bash
kubectl rollout status deployment/nginx-deployment -n dev
```

Kubernetes replaces Pods **one by one** — it brings up a new Pod with the updated image, waits for it to become healthy, then terminates an old one. This ensures **zero downtime** during updates.

### View Rollout History

```bash
kubectl rollout history deployment/nginx-deployment -n dev
```

### Roll Back to the Previous Version

```bash
kubectl rollout undo deployment/nginx-deployment -n dev
kubectl rollout status deployment/nginx-deployment -n dev
```

### Verify the Image After Rollback

```bash
kubectl describe deployment nginx-deployment -n dev | grep Image
```

> **After rollback, the image reverts to `nginx:1.24`** — the version that was running before the update.

---

## Task 7: Cleanup

```bash
kubectl delete deployment nginx-deployment -n dev
kubectl delete pod nginx-dev -n dev
kubectl delete pod nginx-staging -n staging
kubectl delete namespace dev staging production

kubectl get namespaces
kubectl get pods -A
```

> **Warning:** Deleting a namespace removes **everything** inside it. Always double-check before running this in a production environment.

---

## Summary

| Concept | Key Takeaway |
|---|---|
| Namespaces | Logical isolation within a cluster; use for environments, teams, or projects |
| Deployments | Declare desired state (replicas, image); controller maintains it continuously |
| Self-Healing | Deployment controller recreates deleted/crashed pods automatically |
| Scaling | Use `kubectl scale` (imperative) or edit replicas in YAML (declarative) |
| Rolling Update | Zero-downtime image update — pods replaced one by one |
| Rollback | `kubectl rollout undo` reverts to the previous working revision |

---

*Day 52 of #90DaysOfDevOps | #DevOpsKaJosh | #TrainWithShubham*
