# CKA Study Guide Home Lab Users

This guide helps you use your Raspberry Pi K3s cluster to prepare for the **Certified Kubernetes Administrator (CKA)** exam.

## ⚠️ Important Distinction: K3s vs. Kubeadm

The CKA exam uses **Kubeadm** to bootstrap clusters. Your home lab uses **K3s**.

| Feature | CKA Exam (Kubeadm) | Your Home Lab (K3s) |
| :--- | :--- | :--- |
| **Control Plane** | Static Pods in `/etc/kubernetes/manifests` | Processes inside `k3s server` service |
| **Database** | External or stacked `etcd` | Embedded `sqlite` (default) or `etcd` |
| **Container Runtime** | `containerd` (accessed via `crictl`) | `containerd` (embedded in K3s) |
| **CNI (Networking)** | You install it (Calico, Flannel, etc.) | Flannel (Built-in) |
| **Ingress** | You install it (Nginx usually) | Traefik (Built-in) |

> **Strategy**: Use your Pi cluster for **Application Lifecycle**, **Storage**, and **Networking**. Use a Virtual Machine (e.g., VirtualBox/Vagrant) to practice `kubeadm init` and `etcd` backups.

### 🛑 Why not run Kubeadm on this Cluster?
While possible, running standard `kubeadm` + `etcd` on Raspberry Pi 3s (1GB RAM) with SD cards is not recommended because:
1.  **Etcd requires low latency storage**: SD cards are too slow. `etcd` will fail with "sync duration exceeded" errors, causing cluster instability.
2.  **Memory Overhead**: A standard K8s control plane needs ~2GB RAM. Your Pi 3s only have 1GB.
3.  **K3s Optimization**: K3s replaces `etcd` with SQLite (lighter) and combines processes to fit in <512MB RAM.

It is a common misconception that kubeadm and etcd cannot run on Raspberry Pi. They absolutely can, but they generally do not work well on your specific hardware setup (Raspberry Pi 3s with SD cards).

Here is the breakdown of the requirements and why K3s is the better choice for your lab.

1. The etcd Storage Requirement (The Main Blocker)
etcd is the database that stores all Kubernetes cluster data. It requires extremely low disk latency.

Requirement: etcd documentation recommends SSDs with low write latency.
Your Hardware: SD Cards.
The Result: If you run etcd on an SD card, the write latency is too high. etcd will constantly time out, throwing wal: sync duration exceeded errors. This causes the Kubernetes API server to crash repeatedly, making the cluster unusable.
2. Memory (RAM) Requirements
Standard Kubernetes (kubeadm) runs several distinct processes for the control plane (kube-apiserver, kube-controller-manager, kube-scheduler, etcd).

Requirement: A standard control plane node usually needs 2GB+ of RAM to be stable.
Your Hardware: Raspberry Pi 3 B+ has 1GB RAM.
The Result: The node would likely run out of memory (OOM) and crash, or swap heavily (which kills the SD card).
3. Why K3s works instead
K3s is engineered specifically to solve these two problems:

Replaces etcd: By default, K3s uses SQLite (or a shim called Kine). SQLite is much more forgiving of slow storage like SD cards.
Consolidated Processes: K3s combines all those control plane processes into a single binary, significantly reducing the memory footprint (running comfortably on 512MB RAM).
---

## 🎯 Domain 1: Workloads & Scheduling (15%)
*Perfect for your Pi Cluster*

1.  **Node Selectors & Affinity**:
    *   Practice: Force a pod to run only on `pi-worker1`.
    *   Command: `kubectl label nodes pi-worker1 disk=ssd` then use `nodeSelector` in a Pod.
2.  **Taints & Tolerations**:
    *   Practice: Taint `pi-worker2` so no pods can schedule there, then create a Pod that tolerates it.
    *   Command: `kubectl taint nodes pi-worker2 color=blue:NoSchedule`.
3.  **DaemonSets**:
    *   Practice: Deploy a `DaemonSet` that runs a log-viewer on every node.

## 🎯 Domain 2: Storage (10%)
*Perfect for your Pi Cluster*

1.  **Persistent Volumes (PV) & Claims (PVC)**:
    *   Practice: Create a PVC that requests 1Gi of storage.
    *   Note: Your cluster has the `nfs-client` StorageClass. Use it!
    *   Task: Create a Pod that writes a log file to a PVC, delete the Pod, recreate it, and verify the file is still there.

## 🎯 Domain 3: Services & Networking (20%)
*Good for practice, but implementation differs*

1.  **Network Policies**:
    *   Practice: Create a "deny-all" policy for a namespace and try to `curl` a service.
    *   *Note*: K3s supports Network Policies out of the box.
2.  **Services**:
    *   Practice: Expose a deployment via `ClusterIP` and `NodePort`.
    *   Task: Access your `pi-worker1` IP on the NodePort to see if the app responds.

## 🎯 Domain 4: Troubleshooting (30%)
*Mixed Applicability*

1.  **Application Failure**:
    *   Practice: Debug pods with `CrashLoopBackOff`.
    *   Commands: `kubectl logs`, `kubectl describe pod`, `kubectl exec`.
2.  **Node Failure**:
    *   Practice: Shut down `pi-worker2` and see how Kubernetes reschedules pods.
    *   Command: `kubectl get nodes` (will show `NotReady`).

---

## 🛠️ Daily Practice Routine

Don't just read; type the commands!

1.  **Imperative Commands (Speed is key)**:
    *   Create a pod: `kubectl run nginx --image=nginx --restart=Never`
    *   Create a deployment: `kubectl create deploy web --image=nginx --replicas=3`
    *   Expose it: `kubectl expose deploy web --port=80 --target-port=80 --type=NodePort`
    *   Scale it: `kubectl scale deploy web --replicas=5`

2.  **Dry Run**:
    *   Always generate YAML instead of writing from scratch.
    *   `kubectl run my-pod --image=busybox --dry-run=client -o yaml > pod.yaml`

## 📚 Recommended Resources

1.  **Kubernetes Documentation**: You are allowed to keep one tab open to kubernetes.io/docs during the exam. Learn to search it efficiently.
2.  **Killer.sh**: The official exam simulator. It is harder than the real exam.
3.  **Udemy Courses**: Mumshad Mannambeth's CKA course is the gold standard.

## 🧪 Try It Now

Go to `kubernetes/cka-practice/` in this repo and try to fix the broken pod!