
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


# Kubernetes Cluster - Essential Commands Cheat Sheet

## 🚀 Daily Operations

### Check Cluster Health
```bash
# Quick cluster status
kubectl get nodes
kubectl get pods -A
kubectl get svc -A

# Detailed node info
kubectl get nodes -o wide
kubectl describe node pi-master

# Check resource usage
kubectl top nodes
kubectl top pods -A

# Comprehensive health check
./scripts/check-cluster.sh
```

### View Application Status
```bash
# All pods
kubectl get pods --all-namespaces

# Specific namespace
kubectl get pods -n pihole
kubectl get pods -n home
kubectl get pods -n n8n
kubectl get pods -n monitoring

# Watch pods in real-time
watch kubectl get pods -A
kubectl get pods -n pihole -w

# Get pod details
kubectl describe pod <pod-name> -n <namespace>

# Check pod events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### View Logs
```bash
# View logs from a pod
kubectl logs <pod-name> -n <namespace>

# Follow logs (real-time)
kubectl logs -f <pod-name> -n <namespace>

# Last 100 lines
kubectl logs --tail=100 <pod-name> -n <namespace>

# Logs from previous crashed container
kubectl logs <pod-name> -n <namespace> --previous

# Logs from specific container in multi-container pod
kubectl logs <pod-name> -c <container-name> -n <namespace>

# Examples:
kubectl logs -f deployment/pihole -n pihole
kubectl logs -f deployment/grafana -n monitoring
kubectl logs --tail=50 deployment/home-assistant -n home
```

### Access Applications
```bash
# List all services and their IPs
kubectl get svc -A

# Get service details
kubectl describe svc <service-name> -n <namespace>

# Port forward to local machine
kubectl port-forward -n monitoring svc/grafana 3000:3000
kubectl port-forward -n pihole svc/pihole 8080:80

# Access via browser after port-forward:
# http://localhost:3000
```

---

## 🔧 Application Management

### Restart Applications
```bash
# Restart deployment (rolling restart)
kubectl rollout restart deployment/<name> -n <namespace>

# Examples:
kubectl rollout restart deployment/pihole -n pihole
kubectl rollout restart deployment/grafana -n monitoring
kubectl rollout restart deployment/home-assistant -n home

# Force delete and recreate pod
kubectl delete pod <pod-name> -n <namespace>
kubectl delete pod -n pihole -l app=pihole

# Restart all pods in namespace
kubectl delete pods --all -n <namespace>
```

### Scale Applications
```bash
# Scale deployment
kubectl scale deployment/<name> --replicas=2 -n <namespace>

# Example: Scale to 0 (stop), then back to 1 (start)
kubectl scale deployment/n8n --replicas=0 -n n8n
kubectl scale deployment/n8n --replicas=1 -n n8n

# Check scaling status
kubectl get deployment -n <namespace>
```

### Update Applications
```bash
# Update image to newer version
kubectl set image deployment/<name> <container>=<new-image> -n <namespace>

# Example: Update Pi-hole
kubectl set image deployment/pihole pihole=pihole/pihole:2024.01.0 -n pihole

# Check rollout status
kubectl rollout status deployment/<name> -n <namespace>

# Rollback if something breaks
kubectl rollout undo deployment/<name> -n <namespace>

# View rollout history
kubectl rollout history deployment/<name> -n <namespace>
```

### Edit Live Configuration
```bash
# Edit deployment
kubectl edit deployment <name> -n <namespace>

# Edit service
kubectl edit svc <name> -n <namespace>

# Edit configmap
kubectl edit configmap <name> -n <namespace>

# Examples:
kubectl edit deployment pihole -n pihole
kubectl edit deployment grafana -n monitoring
```

---

## 💾 Storage Management

### View Storage
```bash
# List all storage classes
kubectl get storageclass

# List persistent volumes
kubectl get pv

# List persistent volume claims (all namespaces)
kubectl get pvc -A

# Specific namespace
kubectl get pvc -n monitoring

# Describe PVC details
kubectl describe pvc <pvc-name> -n <namespace>

# Check NFS provisioner
kubectl get pods -n nfs-provisioner
kubectl logs -f deployment/nfs-client-provisioner -n nfs-provisioner
```

### Storage Troubleshooting
```bash
# Check what's using storage
kubectl get pvc -A -o wide

# Check PV status
kubectl describe pv <pv-name>

# See storage usage (SSH to master)
ssh isri@10.0.0.154
df -h /mnt/storage
du -sh /mnt/storage/*

# Test NFS mount
showmount -e 10.0.0.154
```

### Backup Data
```bash
# SSH to master
ssh isri@10.0.0.154

# Backup storage
sudo rsync -av /mnt/storage/ /mnt/storage/backups/$(date +%Y%m%d)/

# Backup specific app data
sudo cp -r /mnt/storage/home-assistant /backup/location/

# Create archive
sudo tar -czf homelab-backup-$(date +%Y%m%d).tar.gz /mnt/storage/
```

---

## 🐛 Debugging & Troubleshooting

### Pod Not Starting
```bash
# Get detailed pod info
kubectl describe pod <pod-name> -n <namespace>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# View logs
kubectl logs <pod-name> -n <namespace>

# Execute into running container
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# Examples:
kubectl exec -it deployment/grafana -n monitoring -- /bin/bash
kubectl exec -it deployment/pihole -n pihole -- /bin/sh
```

### Network Issues
```bash
# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup google.com

# Test connectivity between pods
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://pihole.pihole.svc.cluster.local

# Check service endpoints
kubectl get endpoints -n <namespace>

# Describe service
kubectl describe svc <service-name> -n <namespace>

# Check network policies
kubectl get networkpolicies -A
```

### Resource Issues
```bash
# Check node resources
kubectl describe node pi-master
kubectl describe node pi-worker1
kubectl describe node pi-worker2

# Top consumers
kubectl top pods -A --sort-by=memory
kubectl top pods -A --sort-by=cpu

# Check resource requests/limits
kubectl describe pod <pod-name> -n <namespace> | grep -A 5 "Limits:"

# Evicted pods
kubectl get pods -A | grep Evicted
kubectl delete pods -A --field-selector status.phase=Failed
```

### Application-Specific Debug
```bash
# Pi-hole
kubectl exec -it deployment/pihole -n pihole -- pihole status
kubectl exec -it deployment/pihole -n pihole -- pihole -a -p  # Change password

# Grafana - reset admin password
kubectl exec -it deployment/grafana -n monitoring -- grafana-cli admin reset-admin-password newpassword

# Home Assistant - check config
kubectl exec -it deployment/home-assistant -n home -- cat /config/configuration.yaml

# N8n - check workflows
kubectl exec -it deployment/n8n -n n8n -- ls -la /home/node/.n8n/
```

---

## 🔄 Cluster Maintenance

### Update Cluster
```bash
# Update K3s on master
ssh isri@10.0.0.154
curl -sfL https://get.k3s.io | sh -

# Update K3s on workers
ssh isri@10.0.0.156
curl -sfL https://get.k3s.io | K3S_URL=https://10.0.0.154:6443 K3S_TOKEN=<token> sh -

# Or use Ansible
ansible all -i ansible/inventory/hosts.yml -m shell -a "curl -sfL https://get.k3s.io | sh -" -b --ask-vault-pass
```

### Drain Node for Maintenance
```bash
# Safely drain node (moves pods elsewhere)
kubectl drain pi-worker1 --ignore-daemonsets --delete-emptydir-data

# Perform maintenance (SSH, reboot, etc.)
ssh isri@10.0.0.156
sudo reboot

# Mark node back as schedulable
kubectl uncordon pi-worker1
```

### Cordon Node (Prevent Scheduling)
```bash
# Prevent new pods from scheduling on node
kubectl cordon pi-worker1

# Allow scheduling again
kubectl uncordon pi-worker1

# Check node status
kubectl get nodes
```

### Node Cleanup
```bash
# Delete evicted/failed pods
kubectl delete pods --all-namespaces --field-selector status.phase=Failed

# Remove unused images (SSH to each node)
ssh isri@10.0.0.154
sudo k3s crictl rmi --prune

# Clean up old data
sudo find /var/lib/rancher/k3s -type f -name "*.log" -mtime +7 -delete
```

---

## 📊 Monitoring & Metrics

### Cluster Metrics
```bash
# Overall cluster status
kubectl cluster-info

# Component status
kubectl get componentstatuses

# API server health
kubectl get --raw='/healthz?verbose'

# Metrics summary
kubectl top nodes
kubectl top pods -A

# Detailed resource usage
kubectl describe node pi-master | grep -A 5 "Allocated resources"
```

### Application Metrics
```bash
# Prometheus metrics (from command line)
curl http://10.0.0.154:30090/api/v1/query?query=up

# Grafana health check
curl http://10.0.0.154:30080/api/health

# Pi-hole stats
curl http://10.0.0.100/admin/api.php

# Check ingress traffic
kubectl logs -n pihole deployment/pihole | grep "query"
```

### Events & Audit
```bash
# Recent cluster events
kubectl get events -A --sort-by='.lastTimestamp' | head -50

# Watch events live
kubectl get events -A --watch

# Audit logs (if enabled)
kubectl logs -n kube-system kube-apiserver-pi-master
```

---

## 🗑️ Cleanup & Removal

### Remove Applications
```bash
# Delete entire namespace (removes all apps inside)
kubectl delete namespace pihole
kubectl delete namespace n8n
kubectl delete namespace home
kubectl delete namespace monitoring

# Delete specific deployment
kubectl delete deployment <name> -n <namespace>

# Delete service
kubectl delete svc <name> -n <namespace>

# Delete PVC (WARNING: deletes data!)
kubectl delete pvc <pvc-name> -n <namespace>
```

### Clean Up Failed Resources
```bash
# Remove failed pods
kubectl delete pods --field-selector status.phase=Failed -A

# Remove completed jobs
kubectl delete jobs --field-selector status.successful=1 -A

# Remove orphaned PVs
kubectl delete pv <pv-name>
```

### Full Cluster Reset
```bash
# Uninstall K3s from master
ssh isri@10.0.0.154
sudo /usr/local/bin/k3s-uninstall.sh

# Uninstall K3s from workers
ssh isri@10.0.0.156
sudo /usr/local/bin/k3s-agent-uninstall.sh

ssh isri@10.0.0.157
sudo /usr/local/bin/k3s-agent-uninstall.sh

# Reinstall cluster
ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/02-install-k3s.yml --ask-vault-pass
```

---

## 🔐 Security Operations

### Secrets Management
```bash
# Create secret
kubectl create secret generic my-secret --from-literal=password=mypassword -n <namespace>

# View secrets
kubectl get secrets -A

# Decode secret
kubectl get secret <secret-name> -n <namespace> -o jsonpath='{.data.password}' | base64 -d

# Delete secret
kubectl delete secret <secret-name> -n <namespace>
```

### RBAC
```bash
# View service accounts
kubectl get serviceaccounts -A

# View roles
kubectl get roles -A
kubectl get clusterroles

# View role bindings
kubectl get rolebindings -A
kubectl get clusterrolebindings

# Check what you can do
kubectl auth can-i get pods
kubectl auth can-i create deployments -n default
```

### Network Policies
```bash
# View network policies
kubectl get networkpolicies -A

# Create network policy
kubectl apply -f network-policy.yaml

# Test connectivity
kubectl run test --rm -it --image=busybox -- wget -O- http://service-name
```

---

## 📝 Configuration Management

### ConfigMaps
```bash
# Create configmap
kubectl create configmap my-config --from-literal=key=value -n <namespace>

# View configmaps
kubectl get configmaps -A

# Edit configmap
kubectl edit configmap <name> -n <namespace>

# Delete configmap
kubectl delete configmap <name> -n <namespace>
```

### Apply YAML Changes
```bash
# Apply single file
kubectl apply -f deployment.yaml

# Apply directory
kubectl apply -f ./kubernetes/apps/

# Apply with specific namespace
kubectl apply -f deployment.yaml -n <namespace>

# Dry run (test without applying)
kubectl apply -f deployment.yaml --dry-run=client

# Delete resources
kubectl delete -f deployment.yaml
```

---

## 🔄 GitOps Workflows

### Update from Git
```bash
# Pull latest changes
cd ~/homelab-pi-cluster
git pull

# Apply updated manifests
kubectl apply -f kubernetes/storage/
kubectl apply -f kubernetes/apps/

# Restart affected deployments
kubectl rollout restart deployment/<name> -n <namespace>
```

### Version Control
```bash
# Save current state
kubectl get all -A -o yaml > cluster-backup.yaml

# Commit changes
git add .
git commit -m "Update configuration"
git push
```

---

## 📊 Performance Tuning

### Optimize Resource Limits
```bash
# Check current limits
kubectl describe deployment <name> -n <namespace> | grep -A 10 "Limits"

# Update limits
kubectl set resources deployment/<name> -n <namespace> \
  --limits=cpu=500m,memory=512Mi \
  --requests=cpu=100m,memory=256Mi
```

### Horizontal Pod Autoscaling
```bash
# Create HPA
kubectl autoscale deployment <name> --cpu-percent=50 --min=1 --max=3 -n <namespace>

# View HPA status
kubectl get hpa -A

# Delete HPA
kubectl delete hpa <name> -n <namespace>
```

---

## 🆘 Emergency Procedures

### Cluster Not Responding
```bash
# Check master node
ssh isri@10.0.0.154
sudo systemctl status k3s

# Restart K3s
sudo systemctl restart k3s

# Check logs
sudo journalctl -u k3s -f
```

### Pod Stuck in CrashLoopBackOff
```bash
# Get pod details
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous

# Force delete
kubectl delete pod <pod-name> -n <namespace> --grace-period=0 --force
```

### Storage Full
```bash
# Check storage
ssh isri@10.0.0.154
df -h /mnt/storage

# Find large files
du -sh /mnt/storage/* | sort -h

# Clean up old data
sudo rm -rf /mnt/storage/backups/old-backup/
```

### Network Unreachable
```bash
# Check services
kubectl get svc -A

# Check endpoints
kubectl get endpoints -A

# Restart networking (K3s handles this)
sudo systemctl restart k3s
```

---

## 📚 Useful Aliases

Add to `~/.bashrc` or `~/.zshrc`:

```bash
# Kubectl shortcuts
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kgs='kubectl get svc -A'
alias kgn='kubectl get nodes'
alias kdp='kubectl describe pod'
alias kl='kubectl logs'
alias klf='kubectl logs -f'
alias kex='kubectl exec -it'
alias kctx='kubectl config use-context'

# Namespace shortcuts
alias kpi='kubectl get pods -n pihole'
alias khome='kubectl get pods -n home'
alias kmon='kubectl get pods -n monitoring'
alias kn8n='kubectl get pods -n n8n'

# Common operations
alias kwatch='watch kubectl get pods -A'
alias ktop='kubectl top nodes && kubectl top pods -A'
alias kevents='kubectl get events -A --sort-by=.lastTimestamp'

# Application access
alias pihole-logs='kubectl logs -f deployment/pihole -n pihole'
alias grafana-logs='kubectl logs -f deployment/grafana -n monitoring'
alias ha-logs='kubectl logs -f deployment/home-assistant -n home'
```

---

## 🎯 Quick Reference Card

```
=== QUICK COMMANDS ===
Status:     kubectl get pods -A
Logs:       kubectl logs -f <pod> -n <namespace>
Exec:       kubectl exec -it <pod> -n <namespace> -- /bin/bash
Restart:    kubectl rollout restart deployment/<name> -n <namespace>
Scale:      kubectl scale deployment/<name> --replicas=N -n <namespace>
Delete:     kubectl delete pod <pod> -n <namespace>
Events:     kubectl get events -n <namespace> --sort-by=.lastTimestamp
Resources:  kubectl top nodes && kubectl top pods -A

=== ACCESS URLs ===
Pi-hole:    http://10.0.0.100/admin 
Home Assistant: http://10.0.0.101:8123
N8n:        http://10.0.0.102:5678 
Prometheus: http://10.0.0.154:30090
Grafana:    http://10.0.0.154:30080 
```

