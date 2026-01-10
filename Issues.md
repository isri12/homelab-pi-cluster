## errors with run with sudo for all nodes
``` bash
echo '$ROOT_USER ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/010_isri-nopasswd
sudo chmod 0440 /etc/sudoers.d/010_ROOT_USER-nopasswd
sudo whoami 
```

## cgroup Issue

```bash
ssh isri@10.0.0.156

# Check what the master has
ssh isri@10.0.0.155 "cat /boot/firmware/cmdline.txt"

# On worker, create a proper cmdline.txt
# Replace the content with a typical Raspberry Pi boot line + cgroups
sudo nano /boot/firmware/cmdline.txt
```

A typical cmdline.txt should look like this (all on ONE line):
```bash
console=serial0,115200 console=tty1 root=PARTUUID=xxxxxxxx-02 rootfstype=ext4 fsck.repair=yes rootwait cfg80211.ieee80211_regdom=MD cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory

```
Check the cmdline.txt file content: This confirms the file is not corrupted and has the cgroup parameters.
```bash
ansible workers -i ansible/inventory/hosts.yml -m shell -a "cat /boot/firmware/cmdline.txt" --ask-vault-pass

```
Verify Cgroups are Active
```bash
ansible workers -i ansible/inventory/hosts.yml -m shell -a "cat /proc/cgroups | grep memory" --ask-vault-pass
```

The issue is that your cmdline.txt file was technically "correct" (it had the enable flags), so the playbook skipped updating it. However, it missed two critical things:

cgroup_disable=memory is still active: Your debug output shows Kernel booted with: ... cgroup_disable=memory .... This flag overrides your enable settings. It is likely hiding in a different file (like nobtcmd.txt or syscfg.txt) that the previous playbook run failed to clean because the specific file check passed or didn't find it.
swapaccount=1 is missing: The previous playbook run skipped adding this because it saw the other flags were present and exited early ("no_change").
I have updated the playbook to be much more aggressive. It will now:

Force an update if swapaccount=1 is missing (which it is).
Scan ALL text files in /boot/firmware/ to find and destroy cgroup_disable=memory, wherever it is hiding.


he output of cat /proc/cmdline confirms the issue:

cgroup_disable=memory is present: This flag is active in the running kernel, overriding your settings.
cgroup_enable=... is missing: The enable flags you added to /boot/firmware/cmdline.txt are not in the running kernel.

```bash
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/fix-cgroups-workers.yml --ask-vault-pass

```

✅ works on cgroup v1
❌ fails on cgroup v2
```bash
cat /proc/cgroups | grep memory
```



Excellent diagnostics — this output tells us **exactly what’s wrong now**.
You’re not misconfiguring Ansible anymore; this is a **kernel capability issue**.

---

## What your outputs mean (plain English)

### 1️⃣ `stat -fc %T /sys/fs/cgroup`

```text
UNKNOWN (0x63677270)
```

This hex value (`0x63677270`) decodes to **`cgrp`** → a generic cgroup filesystem.

👉 This usually means:

* You are on **cgroup v2**
* But with a **custom or limited kernel build** (common on Raspberry Pi)

---

### 2️⃣ `cgroup.controllers` output (this is the smoking gun)

```text
cpuset cpu io hugetlb pids rdma misc dmem
```

❌ **`memory` is missing**

That means:

> **The Linux kernel on this node was built WITHOUT memory cgroup support**

No amount of boot parameters or Ansible fixes can enable it — the kernel simply does not have it.

---

## Why this happens on Raspberry Pi

Many Raspberry Pi kernels (especially:

* Ubuntu preinstalled images
* Raspberry Pi OS variants
* Lightweight or custom ARM kernels)

are built **without**:

```text
CONFIG_MEMCG=y
CONFIG_MEMCG_SWAP=y
```

To save memory and reduce kernel size.

Your master node works because it’s running a **different kernel build**.

---

## Why Kubernetes cares (critical)

Kubernetes **requires memory cgroups** to:

* Enforce pod memory limits
* Prevent node-wide OOM kills
* Pass kubelet preflight checks

Without it:

* Worker **will not join** the cluster
* Or pods will be evicted / kubelet will fail

---

## Confirm the kernel limitation (optional but definitive)

Run this on the worker:

```bash
zgrep MEMCG /proc/config.gz
```

You will likely see:

```text
# CONFIG_MEMCG is not set
```

That confirms it 100%.

---

## Your options (no magic here)

### ✅ Option 1 (RECOMMENDED): Install a kernel with memory cgroups enabled

This is what most successful Pi Kubernetes clusters do.

#### Ubuntu on Raspberry Pi

Make sure you are using the **generic Ubuntu kernel**, not a Pi-optimized minimal one:

```bash
uname -r
```

If it looks Pi-specific, reinstall:

```bash
sudo apt install --reinstall linux-generic
sudo reboot
```

(Exact package depends on Ubuntu version.)

---

#### Raspberry Pi OS

Use the **full kernel**, not `-v7l` minimal builds:

```bash
sudo apt install raspberrypi-kernel
sudo reboot
```

---

### ✅ Option 2: Rebuild the kernel (advanced, slower)

Only if you want full control.

Steps (high level):

1. Clone Raspberry Pi kernel
2. Enable:

   * `CONFIG_MEMCG`
   * `CONFIG_MEMCG_SWAP`
3. Build & install
4. Reboot

⚠️ This is **advanced** and usually unnecessary unless you enjoy kernel work.

---

### ❌ Option 3: Ignore memory cgroups (not viable)

Kubernetes **will not be stable** without them.
This is not recommended and will break scheduling.

---

## Why your Ansible playbook is now correct

Your playbook:

* Removed `cgroup_disable=memory` ✅
* Added correct boot parameters ✅
* Rebooted nodes correctly ✅

The **hardware kernel simply does not support memory cgroups**.

This is the **final blocker**.

---

## TL;DR (clear conclusion)

* You are on **cgroup v2**
* `memory` controller is **missing**
* Kernel was built **without memory cgroup support**
* This cannot be fixed via boot args or Ansible
* You must install or use a **kernel that enables `CONFIG_MEMCG`**

---

If you want, tell me:

* Your **OS** (Ubuntu 20.04 / 22.04 / Pi OS)
* Output of `uname -a` from master & worker

I’ll tell you **exactly which kernel package** to install so your workers match the master and Kubernetes will finally be happy.

Perfect — that `uname -a` explains everything.

---

## What this kernel is (and why it breaks memory cgroups)

```text
Linux rpiWorkNode1 6.17.0-1006-raspi #6-Ubuntu SMP PREEMPT_DYNAMIC aarch64
```

Key part:

> **`-raspi` kernel flavor**

This is the **Ubuntu Raspberry Pi–optimized kernel**, not the generic Ubuntu kernel.

### ❌ Problem with `linux-raspi`

The `raspi` kernel is built for:

* Low memory usage
* Embedded workloads

As a result, it is commonly built **without memory cgroups** → exactly what you’re seeing:

```text
cgroup.controllers: cpuset cpu io hugetlb pids ...
(no memory)
```

So even though:

* Boot args are correct ✅
* Ansible did its job ✅

👉 **The kernel itself does not support memory cgroups**

---

## Why your master works but workers don’t

Your **master node** is almost certainly running:

* `linux-generic` (or a different build with `CONFIG_MEMCG=y`)

Your **workers** are running:

* `linux-raspi` ❌

Kubernetes requires **consistent cgroup support across nodes**.

---

## ✅ The correct fix (recommended)

### Switch workers to the **generic Ubuntu kernel**

This is the standard fix for Kubernetes on Raspberry Pi with Ubuntu.

---

### 1️⃣ Install generic kernel

```bash
sudo apt update
sudo apt install -y linux-generic
```

This installs a kernel **with memory cgroups enabled**.

---

### 2️⃣ Reboot

```bash
sudo reboot
```

---

### 3️⃣ Verify after reboot

#### Kernel flavor

```bash
uname -a
```

You should see something like:

```text
Linux rpiWorkNode1 6.x.x-xx-generic ...
```

❌ No `-raspi` at the end

---

#### Memory controller (this is the real test)

```bash
cat /sys/fs/cgroup/cgroup.controllers
```

Expected to include:

```text
memory
```

---

## Optional: remove raspi kernel later (cleanup)

Once confirmed working:

```bash
sudo apt remove linux-image-*-raspi linux-modules-*-raspi
```

(Not required immediately; safe to leave installed.)

---

## Kubernetes compatibility (important reassurance)

* Kubernetes **1.25+ fully supports cgroup v2**
* `linux-generic` + cgroup v2 + memory controller = ✅
* containerd + systemd cgroups = ✅

After this:

* Workers will join the cluster
* Pod memory limits will work
* No more cgroup errors

---

## TL;DR (final answer)

* Your workers run **`linux-raspi`**
* That kernel **does not include memory cgroups**
* Boot parameters and Ansible are already correct
* **Install `linux-generic` and reboot**
* Memory cgroups will appear immediately

---

If you want, I can:

* Give you an **Ansible task** to switch kernels on all workers safely
* Help verify **containerd + kubelet** settings after reboot
* Check your **master kernel** to ensure consistency

Just say 👍
-----------------------

Great, this confirms the **root cause very clearly** 👍
Your **master works not because it’s `-raspi`, but because it’s a *different raspi kernel build***.

---

## What’s actually going on (important distinction)

### Master kernel

```text
6.8.0-1043-raspi
```

### Worker kernel

```text
6.17.0-1006-raspi
```

Both are `-raspi`, **but they are NOT equivalent**.

👉 Ubuntu’s Raspberry Pi kernels are **not consistent across versions**:

* Some `-raspi` builds **include memory cgroups**
* Some newer / experimental ones **do not**

Your **worker kernel (6.17)** is missing `CONFIG_MEMCG`
Your **master kernel (6.8)** includes it

That’s why:

* Master: memory cgroup available ✅
* Workers: memory controller missing ❌

---

## Why this breaks Kubernetes

Kubernetes requires:

* **memory cgroups on every node**
* **consistent cgroup behavior**

Mixed support = kubelet failures, scheduling issues, pod crashes.

---

## ✅ Best practice fix (what you should do)

### **Standardize all nodes on the SAME kernel flavor**

You have two **safe** choices:

---

## 🔹 Option A (RECOMMENDED): Use `linux-generic` everywhere

This is the **most stable and predictable** option for Kubernetes.

### On **master and workers**:

```bash
sudo apt update
sudo apt install -y linux-generic
sudo reboot
```

After reboot, verify:

```bash
uname -a
# should show: -generic
```

```bash
cat /sys/fs/cgroup/cgroup.controllers | grep memory
# should show: memory
```

✅ This avoids future raspi-kernel regressions.

---

## 🔹 Option B (acceptable but riskier): Pin to the SAME raspi kernel

If you want to stay on raspi kernels:

1. **Downgrade workers** to the master’s kernel version
2. **Hold** that version so it doesn’t auto-upgrade

Example (conceptual):

```bash
sudo apt install linux-image-6.8.0-1043-raspi linux-modules-6.8.0-1043-raspi
sudo apt-mark hold linux-image-raspi linux-modules-raspi
sudo reboot
```

⚠️ This works but is fragile — future updates may reintroduce the issue.

---

## Why Option A is better

| Reason               | linux-generic      |
| -------------------- | ------------------ |
| Memory cgroups       | Always enabled     |
| Kubernetes support   | Excellent          |
| Consistency          | High               |
| Surprise regressions | Very low           |
| Pi-specific tuning   | Not needed for K8s |

---

## After kernel fix (important checklist)

After switching kernels:

1. Confirm memory controller:

   ```bash
   cat /sys/fs/cgroup/cgroup.controllers
   ```

2. Confirm kubelet uses systemd cgroups:

   ```bash
   ps -ef | grep kubelet | grep cgroup
   ```

3. Re-run your Ansible playbook verification (updated v2-safe check)

---

## TL;DR

* Both nodes use `-raspi`, but **different builds**
* Worker kernel **lacks memory cgroups**
* Master kernel **has them**
* Kubernetes needs **uniform support**

---

If you want, I can:

* Write an **Ansible role** to standardize kernels cluster-wide
* Add **guard checks** so this never happens again
* Help you clean up old raspi kernels safely

Just say 👍


--- 

```bash
sudo nano /boot/firmware/cmdline.txt
```
```bash
cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1
```
```bash
cat /sys/fs/cgroup/cgroup.controllers
cat /proc/cmdline
cat /proc/cgroups | grep memory
```

```bash
cat /boot/firmware/cmdline.txt
cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 systemd.unified_cgroup_hierarchy=0 swapaccount=1 console=serial0,115200 multipath=off dwc_otg.lpm_enable=0 console=tty1 root=LABEL=writable rootfstype=ext4 rootwait fixrtc

```

```bash
cat /proc/cmdline
coherent_pool=1M 8250.nr_uarts=1 snd_bcm2835.enable_headphones=0 cgroup_disable=memory snd_bcm2835.enable_headphones=1 snd_bcm2835.enable_hdmi=1 snd_bcm2835.enable_hdmi=0  vc_mem.mem_base=0x3ec00000 vc_mem.mem_size=0x40000000  console=ttyS0,115200 multipath=off dwc_otg.lpm_enable=0 console=tty1 root=LABEL=writable rootfstype=ext4 panic=10 rootwait fixrtc
```

------------------------------------------------------------

This report is incredibly helpful. It confirms the exact "hidden" mechanism blocking you.

### The Breakdown of the Problem

Look at your **Section 1 (Current Runtime Status)**:

> `coherent_pool=1M ... **cgroup_disable=memory** ...`

Now look at your **Section 2 (Boot Configuration Files)**:
Your `cmdline.txt` **does not** have `cgroup_disable=memory` in it.

**This means the Raspberry Pi Firmware is injecting that disable flag into the kernel before the OS even starts.** This is a known behavior on Pi 3B hardware to save a few megabytes of RAM, but it breaks Kubernetes.

---

### The Fix: Force the Override

Since the firmware is ignoring your `cmdline.txt`, we need to use a "Priority" method to stop the firmware from being "helpful."

#### 1. Edit `/boot/firmware/config.txt`

You have the right flags at the bottom, but the `os_prefix` at the top of your file is likely causing the Pi to look in subfolders (like `/boot/firmware/current/`) for the real files.

Run:

```bash
sudo nano /boot/firmware/config.txt

```

Find the `[all]` section at the very bottom and make sure it looks **exactly** like this:

```text
[all]
# This is the "Magic" flag that tells the firmware to STOP injecting its own ideas
disable_commandline_tags=1
cgroup_enable=memory
cgroup_memory=1

```

#### 2. Create the `extraargs.txt` file

On newer Ubuntu Pi images (like your 25.10 "Questing Quokka"), the bootloader often looks for a file called `extraargs.txt` to append flags that are guaranteed to be at the end of the command line.

```bash
sudo nano /boot/firmware/extraargs.txt

```

Paste this single line:

```text
cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 swapaccount=1 systemd.unified_cgroup_hierarchy=0

```

#### 3. Deal with the `os_prefix` (The likely culprit)

Your report shows:

```text
[all]
os_prefix=current/

```

This means your Pi is likely booting from `/boot/firmware/current/cmdline.txt` instead of `/boot/firmware/cmdline.txt`.

**Check if that directory exists:**

```bash
ls /boot/firmware/current/

```

If it exists, **copy your good `cmdline.txt` into it**:

```bash
sudo cp /boot/firmware/cmdline.txt /boot/firmware/current/cmdline.txt

```

---

### Final Step: The Reboot

After making these changes, sync and reboot:

```bash
sync
sudo reboot

```

### Why this is different for you

You are using **Ubuntu 25.10**, which is a very new/experimental version. It uses a "Tryboot" mechanism (as seen in your `config.txt`) that allows for safe kernel upgrades. This mechanism often hides the "active" `cmdline.txt` inside an `os_prefix` folder.

**After you reboot, run `cat /proc/cmdline` one more time. If you still see `cgroup_disable=memory`, we will need to comment out that `os_prefix=current/` line in `config.txt`. Shall we check that after the reboot?**



```bash
isri@rpiWorkNode1:~$ cat /boot/firmware/current/cmdline.txt 

cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 console=serial0,115200 multipath=off dwc_otg.lpm_enable=0 console=tty1 root=LABEL=writable rootfstype=ext4 rootwait fixrtc

isri@rpiWorkNode1:~$ cat /proc/cmdline

coherent_pool=1M 8250.nr_uarts=1 snd_bcm2835.enable_headphones=0 cgroup_disable=memory snd_bcm2835.enable_headphones=1 snd_bcm2835.enable_hdmi=1 snd_bcm2835.enable_hdmi=0  vc_mem.mem_base=0x3ec00000 vc_mem.mem_size=0x40000000  cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1 console=ttyS0,115200 multipath=off dwc_otg.lpm_enable=0 console=tty1 root=LABEL=writable rootfstype=ext4 rootwait fixrtc

```

choosing Work 1 and Work 2
Raspberry pi Model 3 B+ 
Raspberry Pi OS Lite  

https://valentevidal.medium.com/crafting-a-local-kubernetes-cluster-using-k3s-and-raspberry-pies-a65905bbaca6

#1 Modify /boot/cmdline.txtand add cgroup_memory=1 cgroup_enable=memory
$ cat /boot/firmware/cmdline.txt
console=serial0,115200 console=tty1 root=PARTUUID=4967eadf-02 rootfstype=ext4 fsck.repair=yes rootwait cfg80211.ieee80211_regdom=GB

#2 add arm_64bit=1 at the end of the file /boot/firmware/config.txt
/boot/firmware/config.txt

[all]
arm_64bit=1


Master
inatall K3S
curl -sfL https://get.k3s.io | sh -

Get the token:
sudo cat /var/lib/rancher/k3s/server/node-token
K10231dddbbca12c50083422a9922c770fbe008008cf18fdf84db54c7845340bc45::server:f2720e3ef3d1688de578d0852025b62c

Get the Master IP:
hostname -I | awk '{print $1}'

K3S_URL=https://10.0.0.154:6443 
K3S_TOKEN=


Worker 1 &2
curl -sfL https://get.k3s.io | K3S_URL=https://<MASTER_IP>:6443 K3S_TOKEN=<NODE_TOKEN> sh -


--------------

cat << 'EOF' > install_k3s_worker.sh
#!/bin/bash
echo "Preparing K3s Worker Installation..."

read -p "Enter Master IP: " MASTER_IP
read -p "Enter Node Token: " NODE_TOKEN

# Join the cluster
curl -sfL https://get.k3s.io | K3S_URL=https://${MASTER_IP}:6443 K3S_TOKEN=${NODE_TOKEN} sh -

echo "Worker installation initiated. Check status on Master with 'kubectl get nodes'"
EOF

chmod +x install_k3s_worker.sh
./install_k3s_worker.sh


---------------


sudo kubectl get nodes

sudo kubectl describe node rpiWorkNode1 | grep -i memory

Check Component Health:
sudo kubectl get pods -A

Check Resource Usage:
sudo kubectl top nodes

Check Detailed Node Stats:
sudo kubectl get nodes -o wide

Run a "Network Test" Pod
sudo kubectl run dns-test --image=busybox:1.28 --rm -it -- restart=Never -- nslookup google.com

Check for "Taints" and "Labels":
sudo kubectl get nodes --show-labels

--
sudo kubectl drain worker-pi-1 --ignore-daemonsets --delete-emptydir-data
# On Master
sudo systemctl stop k3s
sudo systemctl restart k3s
On Worker: 
# On Worker: Stop the agent service
sudo systemctl stop k3s-agent
sudo systemctl restart k3s-agent
sudo reboot

# Remove stale nodes
sudo kubectl delete node rpimaster worker-pi-1

# Uncordon pi-worker1 (it is marked as SchedulingDisabled)
sudo kubectl uncordon pi-worker1
