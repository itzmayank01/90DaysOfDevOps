# Day 51 – Kubernetes Manifests and Your First Pods

> 📁 **Project Folder:** [2026/day-51/ on GitHub](https://github.com/itzmayank01/90DaysOfDevOps/tree/master/2026/day-51)

---

## The Four Required Fields of a Kubernetes Manifest

Every Kubernetes resource YAML file must include these four top-level fields:

| Field | Purpose |
|-------|---------|
| `apiVersion` | Specifies which Kubernetes API version/group to use (e.g., `v1` for Pods) |
| `kind` | The type of resource being created (e.g., `Pod`, `Deployment`, `Service`) |
| `metadata` | Identity of the resource — `name` is required; `labels` are optional key-value pairs for organization and selection |
| `spec` | The desired state — defines what containers to run, which images, ports, commands, etc. |

---

## Pod Manifests

### 1. Nginx Pod (`nginx-pod.yaml`)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
  - name: nginx
    image: nginx:latest
    ports:
    - containerPort: 80
```

**Apply & Verify:**
```bash
kubectl apply -f nginx-pod.yaml
kubectl get pods
kubectl exec -it nginx-pod -- /bin/bash
# Inside container:
curl localhost:80
```

---

### 2. BusyBox Pod (`busybox-pod.yaml`)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox-pod
  labels:
    app: busybox
    environment: dev
spec:
  containers:
  - name: busybox
    image: busybox:latest
    command: ["sh", "-c", "echo Hello from BusyBox && sleep 3600"]
```

**Apply & Verify:**
```bash
kubectl apply -f busybox-pod.yaml
kubectl get pods
kubectl logs busybox-pod
# Output: Hello from BusyBox
```

> **Note:** The `command` field keeps BusyBox running. Without it, the container exits immediately and the Pod enters `CrashLoopBackOff`.

---

### 3. Multi-Label Pod (`multi-label-pod.yaml`)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-label-pod
  labels:
    app: myapp
    environment: staging
    team: backend
    version: "1.0"
spec:
  containers:
  - name: alpine
    image: alpine:latest
    command: ["sh", "-c", "echo Multi-label pod running && sleep 3600"]
```

**Apply & Verify:**
```bash
kubectl apply -f multi-label-pod.yaml
kubectl get pods --show-labels
kubectl get pods -l environment=staging
kubectl get pods -l team=backend
```

---

## Imperative vs Declarative

### Declarative (Recommended for Production)
```bash
# Write a YAML file, then apply it
kubectl apply -f nginx-pod.yaml
```
- Uses manifest files checked into version control
- Reproducible and auditable
- `kubectl apply` creates **or updates** resources
- Preferred for production and GitOps workflows

### Imperative (Quick/Ad-hoc)
```bash
# Create a pod directly without YAML
kubectl run redis-pod --image=redis:latest
```
- Faster for one-off tasks and debugging
- Not version-controlled or easily reproducible
- Useful for generating YAML scaffolds:

```bash
# Generate YAML without creating the resource
kubectl run test-pod --image=nginx --dry-run=client -o yaml
```

**Key Difference:** Declarative manifests represent the *desired state* that Kubernetes continuously reconciles. Imperative commands are one-time instructions with no persistent definition.

---

## Validation Before Applying

```bash
# Client-side validation (checks YAML structure)
kubectl apply -f nginx-pod.yaml --dry-run=client

# Server-side validation (checks against cluster API)
kubectl apply -f nginx-pod.yaml --dry-run=server
```

**Error when `image` field is missing:**
```
error: error validating "nginx-pod.yaml": error validating data: 
ValidationError(Pod.spec.containers[0]): missing required field "image"
```

---

## Label Filtering

```bash
# Show all pods with their labels
kubectl get pods --show-labels

# Filter by label
kubectl get pods -l app=nginx
kubectl get pods -l environment=dev

# Add a label to existing pod
kubectl label pod nginx-pod environment=production

# Remove a label
kubectl label pod nginx-pod environment-
```

---

## Screenshot – Running Pods

> *(Add your `kubectl get pods` screenshot here)*

```
NAME               READY   STATUS    RESTARTS   AGE
nginx-pod          1/1     Running   0          5m
busybox-pod        1/1     Running   0          3m
multi-label-pod    1/1     Running   0          1m
```

---

## What Happens When You Delete a Standalone Pod?

When you delete a standalone Pod (not managed by a controller like Deployment or ReplicaSet):

- **It is permanently deleted** — Kubernetes does not recreate it
- There is no controller watching over it to restore it
- All data in the pod (unless stored in a PersistentVolume) is lost

```bash
kubectl delete pod nginx-pod
# Pod is gone forever — no automatic restart
```

> **This is why in production you use Deployments instead of bare Pods.**  
> A Deployment controller continuously monitors and recreates Pods if they go down.

---

## Cleanup

```bash
# Delete by name
kubectl delete pod nginx-pod
kubectl delete pod busybox-pod
kubectl delete pod multi-label-pod

# Or delete using manifest file
kubectl delete -f nginx-pod.yaml

# Verify
kubectl get pods
```

---

## Key Takeaways

- A Pod is the smallest deployable unit in Kubernetes — it wraps one or more containers
- Manifests always need: `apiVersion`, `kind`, `metadata`, `spec`
- Use `--dry-run=client -o yaml` to scaffold manifests quickly
- Labels are just metadata — powerful for filtering and selection by Services/Deployments
- Standalone Pods are ephemeral — always prefer Deployments for real workloads


> 📸 **Screenshots:** [View Screenshots](https://github.com/itzmayank01/90DaysOfDevOps/tree/master/2026/day-51/Screenshots)
---

*Day 51 of #90DaysOfDevOps | #DevOpsKaJosh | #TrainWithShubham*
