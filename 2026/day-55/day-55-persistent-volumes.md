# Day 55 — Persistent Volumes (PV) and Persistent Volume Claims (PVC)

## Overview

Containers are ephemeral by design — the moment a Pod dies, every file written inside it vanishes. That is acceptable for stateless apps, but a disaster for databases, logs, or anything that needs to survive a restart. Today I explored Kubernetes' storage primitives: **Persistent Volumes (PV)**, **Persistent Volume Claims (PVC)**, and **StorageClasses** for dynamic provisioning.

---

## Why Containers Need Persistent Storage

A container's filesystem is tied to its lifecycle. When Kubernetes restarts a crashed Pod, or when you delete and redeploy it, all in-container data is gone. This means:

- A database Pod loses all rows on restart
- An uploaded file is deleted the moment the serving Pod terminates
- Logs written inside a container disappear before anyone reads them

Kubernetes solves this by decoupling **storage** from **compute**. A PersistentVolume lives independently of any Pod — the data stays even when the Pod that wrote it no longer exists.

---

## Task 1: Demonstrating the Problem — Data Lost on Pod Deletion

### Pod manifest using `emptyDir`

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: ephemeral-pod
spec:
  containers:
    - name: writer
      image: busybox
      command: ["/bin/sh", "-c"]
      args:
        - echo "Written at $(date)" > /data/message.txt && sleep 3600
      volumeMounts:
        - name: temp-storage
          mountPath: /data
  volumes:
    - name: temp-storage
      emptyDir: {}
```

```bash
kubectl apply -f ephemeral-pod.yaml
kubectl exec ephemeral-pod -- cat /data/message.txt
# Written at Mon Mar 30 10:00:00 UTC 2026

kubectl delete pod ephemeral-pod
kubectl apply -f ephemeral-pod.yaml
kubectl exec ephemeral-pod -- cat /data/message.txt
# Written at Mon Mar 30 10:05:00 UTC 2026  ← NEW timestamp, old data gone
```

**Result:** The timestamp is different after recreation — confirming the data was completely lost. The `emptyDir` volume lives and dies with the Pod.

---

## Task 2: Creating a PersistentVolume (Static Provisioning)

A **PersistentVolume** is a piece of storage in the cluster provisioned by an administrator (or manually by us). It is a cluster-level resource — not tied to any namespace.

### PV manifest

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-pv
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  hostPath:
    path: /tmp/k8s-pv-data
```

```bash
kubectl apply -f my-pv.yaml
kubectl get pv
```

**Output:**

```
NAME    CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   AGE
my-pv   1Gi        RWO            Retain           Available           manual         10s
```

**Status is `Available`** — the PV exists but no PVC has claimed it yet.

### Access Modes explained

| Mode | Short | Description |
|---|---|---|
| `ReadWriteOnce` | RWO | Read-write by a **single node** only |
| `ReadOnlyMany` | ROX | Read-only by **many nodes** simultaneously |
| `ReadWriteMany` | RWX | Read-write by **many nodes** simultaneously |

> `hostPath` stores data on the node's local disk at `/tmp/k8s-pv-data`. Fine for learning and local clusters — not for production since data is node-specific.

---

## Task 3: Creating a PersistentVolumeClaim

A **PersistentVolumeClaim** is how a Pod requests storage. Developers write PVCs without needing to know the underlying storage details. Kubernetes binds the PVC to a suitable PV automatically.

### PVC manifest

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
```

```bash
kubectl apply -f my-pvc.yaml
kubectl get pvc
```

**Output:**

```
NAME     STATUS   VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
my-pvc   Bound    my-pv    1Gi        RWO                           5s
```

```bash
kubectl get pv
```

```
NAME    CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM            AGE
my-pv   1Gi        RWO            Retain           Bound    default/my-pvc   60s
```

**Both show `Bound`** — Kubernetes matched the PVC to the PV because:
- The PV capacity (`1Gi`) satisfies the PVC request (`500Mi`)
- The access modes match (`ReadWriteOnce`)

The `VOLUME` column in `kubectl get pvc` shows `my-pv` — confirming which PV was selected.

---

## Task 4: Using the PVC in a Pod — Data That Survives

### Pod manifest with PVC

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: persistent-pod-1
spec:
  containers:
    - name: writer
      image: busybox
      command: ["/bin/sh", "-c"]
      args:
        - echo "Pod 1 wrote this at $(date)" >> /data/message.txt && sleep 3600
      volumeMounts:
        - name: persistent-storage
          mountPath: /data
  volumes:
    - name: persistent-storage
      persistentVolumeClaim:
        claimName: my-pvc
```

```bash
kubectl apply -f persistent-pod-1.yaml
kubectl exec persistent-pod-1 -- cat /data/message.txt
# Pod 1 wrote this at Mon Mar 30 10:10:00 UTC 2026

kubectl delete pod persistent-pod-1
```

Now create a second pod pointing to the same PVC:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: persistent-pod-2
spec:
  containers:
    - name: writer
      image: busybox
      command: ["/bin/sh", "-c"]
      args:
        - echo "Pod 2 wrote this at $(date)" >> /data/message.txt && sleep 3600
      volumeMounts:
        - name: persistent-storage
          mountPath: /data
  volumes:
    - name: persistent-storage
      persistentVolumeClaim:
        claimName: my-pvc
```

```bash
kubectl apply -f persistent-pod-2.yaml
kubectl exec persistent-pod-2 -- cat /data/message.txt
```

**Output:**

```
Pod 1 wrote this at Mon Mar 30 10:10:00 UTC 2026
Pod 2 wrote this at Mon Mar 30 10:15:00 UTC 2026
```

**Both lines are present** ✅ — the data from Pod 1 survived its deletion and was accessible to Pod 2. The PVC kept the data alive independent of any Pod's lifecycle.

---

## Task 5: StorageClasses and Dynamic Provisioning

### Inspecting the default StorageClass

```bash
kubectl get storageclass
```

**Output (Minikube example):**

```
NAME                 PROVISIONER                RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
standard (default)   k8s.io/minikube-hostpath   Delete          Immediate           false                  2d
```

```bash
kubectl describe storageclass standard
```

Key fields:
- **Provisioner:** `k8s.io/minikube-hostpath` — the plugin that creates PVs on demand
- **ReclaimPolicy:** `Delete` — when the PVC is deleted, the PV is also deleted automatically
- **VolumeBindingMode:** `Immediate` — PV is provisioned as soon as the PVC is created

**Default StorageClass:** `standard` (on Minikube)

With dynamic provisioning, developers only need to write a PVC. The StorageClass automatically creates the PV behind the scenes — no admin intervention needed.

---

## Task 6: Dynamic Provisioning in Action

### PVC with StorageClass

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dynamic-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: standard
  resources:
    requests:
      storage: 300Mi
```

```bash
kubectl apply -f dynamic-pvc.yaml
kubectl get pvc
```

**Output:**

```
NAME          STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
my-pvc        Bound    my-pv                                      1Gi        RWO                           10m
dynamic-pvc   Bound    pvc-4a2b8c1d-xxxx-xxxx-xxxx-xxxxxxxxxxxx   300Mi      RWO            standard       5s
```

```bash
kubectl get pv
```

**Output:**

```
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM
my-pv                                      1Gi        RWO            Retain           Bound    default/my-pvc
pvc-4a2b8c1d-xxxx-xxxx-xxxx-xxxxxxxxxxxx   300Mi      RWO            Delete           Bound    default/dynamic-pvc
```

**Two PVs now exist:**
- `my-pv` — created **manually** (static provisioning), Retain policy
- `pvc-4a2b8c1d-...` — created **automatically** by the StorageClass (dynamic provisioning), Delete policy

Used the dynamic PVC in a Pod, wrote data, verified it works ✅

---

## Task 7: Clean Up — Observing Reclaim Policies

```bash
# Step 1: Delete all Pods first
kubectl delete pod persistent-pod-2 ephemeral-pod

# Step 2: Delete both PVCs
kubectl delete pvc my-pvc dynamic-pvc

# Step 3: Check PV status
kubectl get pv
```

**Output after PVC deletion:**

```
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS     CLAIM
my-pv                                      1Gi        RWO            Retain           Released   default/my-pvc
```

- The **dynamic PV** (`pvc-4a2b8c1d-...`) is **gone** — `Delete` reclaim policy removed it automatically when the PVC was deleted
- The **manual PV** (`my-pv`) shows `Released` — `Retain` policy kept it around even after the PVC was gone

```bash
# Step 4: Manually delete the retained PV
kubectl delete pv my-pv
```

### Why does this matter?

| Reclaim Policy | What happens when PVC is deleted | Use case |
|---|---|---|
| `Retain` | PV stays, status becomes `Released`, data preserved | Databases, critical data you want to inspect before deleting |
| `Delete` | PV and underlying storage are removed automatically | Ephemeral workloads, dev/test environments |
| `Recycle` | Data is scrubbed, PV becomes `Available` again | Deprecated — avoid using |

---

## PV Lifecycle Summary

```
Available → Bound → Released → (Retain: manual delete | Delete: auto-removed)
```

- **Available:** PV exists, no PVC has claimed it
- **Bound:** PVC matched and claimed the PV
- **Released:** PVC was deleted, PV still exists with old data (Retain policy)

---

## Static vs Dynamic Provisioning

| | Static Provisioning | Dynamic Provisioning |
|---|---|---|
| **Who creates PV?** | Admin manually | StorageClass provisioner automatically |
| **When PV is created** | Before PVC exists | When PVC is applied |
| **Best for** | Bare-metal, specific hardware | Cloud environments (EBS, GCE PD, Azure Disk) |
| **Developer experience** | Must coordinate with admin | Just write a PVC with `storageClassName` |

---

## Key Takeaways

1. **`emptyDir` is ephemeral** — data dies with the Pod. Never use it for anything you need to keep.
2. **PVs are cluster-scoped, PVCs are namespace-scoped** — a PV can be claimed by any namespace, but PVCs live in one.
3. **Kubernetes binds PVCs to PVs** based on capacity (PV must be ≥ PVC request) and matching access modes.
4. **`Retain` vs `Delete`** is the most important reclaim policy decision — get it wrong and you lose production data.
5. **Dynamic provisioning** is the standard in cloud environments — developers write PVCs and never think about underlying storage.
6. **`hostPath` is for local learning only** — in production, use cloud-native provisioners (EBS, GCE PD, Azure Disk, NFS).

---

## Screenshots

> 📁 All screenshots are stored in the `screenshots/` folder.

| # | Description | File |
|---|---|---|
| 1 | `emptyDir` Pod created and data written | `screenshots/01-emptydir-pod-data.png` |
| 2 | Data gone after Pod deletion and recreation (different timestamp) | `screenshots/02-data-lost-after-recreate.png` |
| 3 | `kubectl get pv` showing PV with `Available` status | `screenshots/03-pv-available.png` |
| 4 | `kubectl apply` for PVC and both showing `Bound` status | `screenshots/04-pvc-bound.png` |
| 5 | `kubectl get pvc` showing VOLUME column with `my-pv` | `screenshots/05-pvc-volume-column.png` |
| 6 | First Pod writing to `/data/message.txt` via PVC | `screenshots/06-pod1-write.png` |
| 7 | Second Pod reading the same file with both messages | `screenshots/07-pod2-data-persisted.png` |
| 8 | `kubectl get storageclass` output | `screenshots/08-storageclass-list.png` |
| 9 | `kubectl describe storageclass standard` output | `screenshots/09-storageclass-describe.png` |
| 10 | Dynamic PVC applied and auto-provisioned PV appearing | `screenshots/10-dynamic-pv-created.png` |
| 11 | `kubectl get pv` showing both manual and dynamic PVs | `screenshots/11-both-pvs.png` |
| 12 | After PVC deletion — dynamic PV gone, manual PV `Released` | `screenshots/12-pv-after-pvc-delete.png` |
| 13 | Final `kubectl get pv` showing empty after manual PV delete | `screenshots/13-cleanup-complete.png` |

---

## References

- [Kubernetes Persistent Volumes Docs](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [StorageClasses](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- [90DaysOfDevOps Challenge](https://github.com/itzmayank01/90DaysOfDevOps)

---

*Day 55 of #90DaysOfDevOps | #DevOpsKaJosh | #TrainWithShubham*
