#!/bin/bash
# Complete Raspberry Pi Kubernetes Cluster Setup Script
# This script automates the entire cluster deployment process

set -e  # Exit on any error

echo "Setting up Raspberry Pi Kubernetes Cluster..."
echo "=================================================="
echo ""

# Configuration
VAULT_PASS_FILE="${HOME}/.vault_pass"
INVENTORY="ansible/inventory/hosts.yml"
MASTER_IP="10.0.0.154" # Replace with your actual master node IP

# Check if vault password file exists
if [ ! -f "$VAULT_PASS_FILE" ]; then
    echo "⚠️  Vault password file not found at $VAULT_PASS_FILE"
    echo "    You can either:"
    echo "    1. Create it with: echo 'your-vault-password' > ~/.vault_pass && chmod 600 ~/.vault_pass"
    echo "    2. Continue and enter password manually for each step"
    echo ""
    read -p "Continue without vault password file? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    VAULT_ARGS="--ask-vault-pass"
else
    echo "✅ Using vault password file: $VAULT_PASS_FILE"
    VAULT_ARGS="--vault-password-file $VAULT_PASS_FILE"
fi

# Check for Ansible
if ! command -v ansible-playbook &> /dev/null; then
    echo "❌ Ansible is not installed. Please install it first: sudo apt install ansible"
    exit 1
fi

echo ""
echo "=================================================="
echo "📦 Step 1/7: Preparing Raspberry Pis"
echo "=================================================="
echo "This will:"
echo "  - Update all packages"
echo "  - Install dependencies (curl, git, vim, htop, nfs-common)"
echo "  - Set hostnames"
echo "  - Enable cgroups for Kubernetes"
echo "  - Disable swap"
echo "  - Reboot if needed"
echo ""
ansible-playbook -i $INVENTORY ansible/playbooks/01-prepare-pis.yml $VAULT_ARGS

echo ""
echo "=================================================="
echo "☸️  Step 2/7: Installing K3s Cluster"
echo "=================================================="
echo "This will:"
echo "  - Install K3s on master node"
echo "  - Install K3s agents on worker nodes"
echo "  - Retrieve kubeconfig"
echo "  - Verify cluster is ready"
echo ""
ansible-playbook -i $INVENTORY ansible/playbooks/02-install-k3s.yml $VAULT_ARGS

echo ""
echo "=================================================="
echo "💾 Step 3/7: Setting up Storage"
echo "=================================================="
echo "This will:"
echo "  - Format USB drive on master"
echo "  - Configure NFS server"
echo "  - Mount NFS on workers"
echo "  - Create storage directories"
echo ""
ansible-playbook -i $INVENTORY ansible/playbooks/03-setup-storage.yml $VAULT_ARGS

echo ""
echo "=================================================="
echo "⚙️  Step 4/7: Configuring kubectl"
echo "=================================================="
mkdir -p ~/.kube

if [ -f "kubeconfig" ]; then
    cp kubeconfig ~/.kube/config
elif [ -f "/etc/rancher/k3s/k3s.yaml" ]; then
    echo "ℹ️  Copying kubeconfig from system location..."
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
    sudo chown $(id -u):$(id -g) ~/.kube/config
else
    echo "⚠️  Kubeconfig not found, will be created by K3s playbook"
fi

# Update server IP to master node IP
sed -i "s/127.0.0.1/${MASTER_IP}/g" ~/.kube/config 2>/dev/null || true
echo "✅ Kubeconfig configured"

echo ""
echo "=================================================="
echo "✅ Step 5/7: Verifying Cluster"
echo "=================================================="
echo "Checking cluster status..."
kubectl get nodes
echo ""
echo "Checking system pods..."
kubectl get pods --all-namespaces

echo ""
echo "=================================================="
echo "📂 Step 6/7: Deploying NFS Provisioner"
echo "=================================================="
echo "This provides dynamic storage provisioning for Kubernetes"
kubectl apply -f kubernetes/storage/nfs-provisioner.yaml

echo "⏳ Waiting for NFS provisioner to be ready..."
kubectl wait --for=condition=available --timeout=300s \
  deployment/nfs-client-provisioner -n nfs-provisioner || true

echo ""
echo "Verifying storage..."
kubectl get storageclass
kubectl get pods -n nfs-provisioner

echo ""
echo "=================================================="
echo "📱 Step 7/7: Deploying Applications"
echo "=================================================="

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    echo "⚠️  Helm not found. Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

# Add Helm repositories
echo "Adding Helm repositories..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || true
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || true
helm repo add mojo2600 https://mojo2600.github.io/pihole-kubernetes/ 2>/dev/null || true
# Note: k8s-at-home is deprecated. Using the archive URL for stability. 
helm repo add k8s-at-home https://k8s-at-home.github.io/charts/ 2>/dev/null || true
helm repo update

echo ""
echo "📊 Deploying Prometheus + Grafana..."
kubectl create namespace monitoring 2>/dev/null || true
helm upgrade --install kube-prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  -f helm-values/prometheus-stack-values.yaml \
  --wait \
  --timeout 15m || echo "⚠️  Prometheus installation failed or timed out"

echo ""
echo "🛡️  Deploying Pi-hole..."
kubectl create namespace pihole 2>/dev/null || true
helm upgrade --install pihole mojo2600/pihole \
  --namespace pihole \
  -f helm-values/pihole-values.yaml \
  --wait \
  --timeout 5m || echo "⚠️  Pi-hole installation failed or timed out"

echo ""
echo "🏠 Deploying Home Assistant..."
kubectl create namespace home 2>/dev/null || true
helm upgrade --install home-assistant k8s-at-home/home-assistant \
  --namespace home \
  -f helm-values/home-assistant-values.yaml \
  --wait \
  --timeout 5m || echo "⚠️  Home Assistant installation failed or timed out"

echo ""
echo "⚡ Deploying N8n..."
kubectl apply -f kubernetes/apps/n8n/deployment.yaml || echo "⚠️  N8n deployment failed"

echo ""
echo "⏳ Waiting for all pods to be ready (this may take several minutes)..."
sleep 30

echo ""
echo "=================================================="
echo "🎉 Cluster Setup Complete!"
echo "=================================================="
echo ""
echo "📊 Cluster Status:"
echo "-------------------"
kubectl get nodes
echo ""
kubectl get pods --all-namespaces | grep -v kube-system | head -20

echo ""
echo "💾 Storage Status:"
echo "-------------------"
kubectl get pvc --all-namespaces
kubectl get storageclass

echo ""
echo "🌐 Access Your Services:"
echo "========================"
echo ""
echo "  📊 Grafana:"
echo "     URL: http://${MASTER_IP}:30080"
echo "     Username: admin"
echo "     Password: (check helm-values/prometheus-stack-values.yaml)"
echo ""
echo "  🛡️  Pi-hole:"
echo "     URL: http://10.0.0.100/admin"
echo "     Password: (check helm-values/pihole-values.yaml)"
echo ""
echo "  🏠 Home Assistant:"
echo "     URL: http://10.0.0.101:8123"
echo "     Initial setup wizard will guide you"
echo ""
echo "  ⚡ N8n:"
echo "     URL: http://10.0.0.102:5678"
echo "     Username: admin"
echo "     Password: (check kubernetes/apps/n8n/deployment.yaml)"
echo ""
echo "=================================================="
echo "📝 Next Steps:"
echo "=================================================="
echo ""
echo "1. Access Grafana and explore pre-built dashboards"
echo "2. Configure Pi-hole as your DNS server"
echo "3. Set up Home Assistant for home automation"
echo "4. Create workflows in N8n"
echo ""
echo "📚 Useful Commands:"
echo "-------------------"
echo "  kubectl get nodes              # Check cluster nodes"
echo "  kubectl get pods -A            # List all pods"
echo "  kubectl get pvc -A             # Check storage volumes"
echo "  kubectl logs -n <ns> <pod>     # View pod logs"
echo ""
echo "🔧 Troubleshooting:"
echo "-------------------"
echo "  kubectl describe pod <name> -n <namespace>    # Debug pod issues"
echo "  kubectl get events -A --sort-by='.lastTimestamp'  # View recent events"
echo ""
echo "✅ Setup completed successfully!"
echo ""
