#!/bin/bash
#
# Deploy Home Lab Applications using Docker Images in Kubernetes
#

set -e

echo "======================================================================"
echo "🐳 Docker-based Kubernetes Application Deployment"
echo "======================================================================"
echo ""

# Configuration
MASTER_IP="10.0.0.154"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    echo "Waiting for $deployment in $namespace..."
    kubectl wait --for=condition=available --timeout=300s \
        deployment/$deployment -n $namespace || print_warning "Timeout waiting for $deployment"
}

echo "======================================================================"
echo "📦 Creating Namespaces"
echo "======================================================================"

kubectl create namespace monitoring 2>/dev/null || print_status "Namespace monitoring exists"
kubectl create namespace pihole 2>/dev/null || print_status "Namespace pihole exists"
kubectl create namespace home 2>/dev/null || print_status "Namespace home exists"
kubectl create namespace n8n 2>/dev/null || print_status "Namespace n8n exists"

print_status "Namespaces ready"

echo ""
echo "======================================================================"
echo "🛡️  Deploying Pi-hole"
echo "======================================================================"

kubectl apply -f - <<YAML
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pihole-data
  namespace: pihole
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-client
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pihole
  namespace: pihole
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pihole
  template:
    metadata:
      labels:
        app: pihole
    spec:
      containers:
      - name: pihole
        image: pihole/pihole:latest
        ports:
        - containerPort: 80
          name: http
        - containerPort: 53
          name: dns-tcp
          protocol: TCP
        - containerPort: 53
          name: dns-udp
          protocol: UDP
        env:
        - name: TZ
          value: "America/New_York"
        - name: WEBPASSWORD
          value: "changeme123"
        - name: DNSMASQ_LISTENING
          value: "all"
        volumeMounts:
        - name: pihole-data
          mountPath: /etc/pihole
        - name: dnsmasq-data
          mountPath: /etc/dnsmasq.d
        resources:
          requests:
            memory: "128Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
      volumes:
      - name: pihole-data
        persistentVolumeClaim:
          claimName: pihole-data
      - name: dnsmasq-data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: pihole
  namespace: pihole
spec:
  type: LoadBalancer
  loadBalancerIP: 10.0.0.100
  selector:
    app: pihole
  ports:
  - name: http
    port: 80
    targetPort: 80
  - name: dns-tcp
    port: 53
    targetPort: 53
    protocol: TCP
  - name: dns-udp
    port: 53
    targetPort: 53
    protocol: UDP
YAML

wait_for_deployment pihole pihole
print_status "Pi-hole deployed"

echo ""
echo "======================================================================"
echo "🏠 Deploying Home Assistant"
echo "======================================================================"

kubectl apply -f - <<YAML
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: home-assistant-config
  namespace: home
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-client
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: home-assistant
  namespace: home
spec:
  replicas: 1
  selector:
    matchLabels:
      app: home-assistant
  template:
    metadata:
      labels:
        app: home-assistant
    spec:
      nodeSelector:
        kubernetes.io/hostname: pi-master
      containers:
      - name: home-assistant
        image: ghcr.io/home-assistant/home-assistant:stable
        ports:
        - containerPort: 8123
          name: http
        env:
        - name: TZ
          value: "America/New_York"
        volumeMounts:
        - name: config
          mountPath: /config
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
      volumes:
      - name: config
        persistentVolumeClaim:
          claimName: home-assistant-config
---
apiVersion: v1
kind: Service
metadata:
  name: home-assistant
  namespace: home
spec:
  type: LoadBalancer
  loadBalancerIP: 10.0.0.101
  selector:
    app: home-assistant
  ports:
  - port: 8123
    targetPort: 8123
YAML

wait_for_deployment home home-assistant
print_status "Home Assistant deployed"

echo ""
echo "======================================================================"
echo "⚡ Deploying N8n"
echo "======================================================================"

kubectl apply -f - <<YAML
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: n8n-data
  namespace: n8n
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-client
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: n8n
  namespace: n8n
spec:
  replicas: 1
  selector:
    matchLabels:
      app: n8n
  template:
    metadata:
      labels:
        app: n8n
    spec:
      nodeSelector:
        kubernetes.io/hostname: pi-master
      containers:
      - name: n8n
        image: n8nio/n8n:latest
        ports:
        - containerPort: 5678
          name: http
        env:
        - name: N8N_BASIC_AUTH_ACTIVE
          value: "true"
        - name: N8N_BASIC_AUTH_USER
          value: "admin"
        - name: N8N_BASIC_AUTH_PASSWORD
          value: "changeme123"
        - name: N8N_HOST
          value: "n8n.local"
        - name: N8N_PORT
          value: "5678"
        - name: N8N_PROTOCOL
          value: "http"
        - name: WEBHOOK_URL
          value: "http://10.0.0.102:5678/"
        - name: GENERIC_TIMEZONE
          value: "America/New_York"
        volumeMounts:
        - name: data
          mountPath: /home/node/.n8n
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: n8n-data
---
apiVersion: v1
kind: Service
metadata:
  name: n8n
  namespace: n8n
spec:
  type: LoadBalancer
  loadBalancerIP: 10.0.0.102
  selector:
    app: n8n
  ports:
  - port: 5678
    targetPort: 5678
YAML

wait_for_deployment n8n n8n
print_status "N8n deployed"

echo ""
echo "======================================================================"
echo "📊 Deploying Prometheus"
echo "======================================================================"

kubectl apply -f - <<YAML
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-data
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-client
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
    
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
        - targets: ['localhost:9090']
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      nodeSelector:
        kubernetes.io/hostname: pi-master
      containers:
      - name: prometheus
        image: prom/prometheus:latest
        args:
        - '--config.file=/etc/prometheus/prometheus.yml'
        - '--storage.tsdb.path=/prometheus'
        - '--storage.tsdb.retention.time=7d'
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: data
          mountPath: /prometheus
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
      volumes:
      - name: config
        configMap:
          name: prometheus-config
      - name: data
        persistentVolumeClaim:
          claimName: prometheus-data
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  type: NodePort
  selector:
    app: prometheus
  ports:
  - port: 9090
    targetPort: 9090
    nodePort: 30090
YAML

wait_for_deployment monitoring prometheus
print_status "Prometheus deployed"

echo ""
echo "======================================================================"
echo "📈 Deploying Grafana"
echo "======================================================================"

kubectl apply -f - <<YAML
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-data
  namespace: monitoring
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: nfs-client
  resources:
    requests:
      storage: 5Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      nodeSelector:
        kubernetes.io/hostname: pi-master
      containers:
      - name: grafana
        image: grafana/grafana:latest
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_USER
          value: "admin"
        - name: GF_SECURITY_ADMIN_PASSWORD
          value: "changeme123"
        volumeMounts:
        - name: data
          mountPath: /var/lib/grafana
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: grafana-data
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: monitoring
spec:
  type: NodePort
  selector:
    app: grafana
  ports:
  - port: 3000
    targetPort: 3000
    nodePort: 30080
YAML

wait_for_deployment monitoring grafana
print_status "Grafana deployed"

echo ""
echo "======================================================================"
echo "🎉 Deployment Complete!"
echo "======================================================================"
echo ""

kubectl get nodes
echo ""
kubectl get pods -A | grep -E "pihole|home|n8n|prometheus|grafana"
echo ""

echo "🌐 Access Your Services:"
echo "========================"
echo ""
echo "  🛡️  Pi-hole:         http://10.0.0.100/admin (password: changeme123)"
echo "  🏠 Home Assistant:  http://10.0.0.101:8123"
echo "  ⚡ N8n:             http://10.0.0.102:5678 (admin/changeme123)"
echo "  📊 Prometheus:      http://10.0.0.154:30090"
echo "  📈 Grafana:         http://10.0.0.154:30080 (admin/changeme123)"
echo ""
echo "✅ All applications deployed!"
