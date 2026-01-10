
# Helpful Commands

## 🖥️ System Information (Raspberry Pi / Linux)

### Hardware & OS Info
```bash
# Kernel version
uname -a

# Raspberry Pi Model
cat /sys/firmware/devicetree/base/model

# CPU Info
cat /proc/cpuinfo

# OS Release Info
lsb_release -a

# Memory Usage
free -h

# Disk Usage
df -h
```

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
#If you know your network name and password, you can connect in a single line.

#List networks to confirm yours is visible:
nmcli device wifi list
#Connect using this command (replace with your details):
sudo nmcli device wifi connect "Your_SSID" password Your_Password"
#Verify the connection:
nmcli connection show --active
```

```bash
sudo vim /etc/hosts
```



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

If the installation playbook finished correctly, your nodes should be labeled. You can verify this with:

```bash
sudo kubectl get nodes --show-labels
```