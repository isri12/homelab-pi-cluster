#!/bin/bash

echo "======================================================================"
echo "🔍 Kubernetes Cluster Health Check"
echo "======================================================================"
echo ""

echo "📊 Cluster Nodes:"
echo "-------------------"
kubectl get nodes -o wide
echo ""

echo "📦 Namespaces:"
echo "-------------------"
kubectl get namespaces
echo ""

echo "🚀 All Pods:"
echo "-------------------"
kubectl get pods -A -o wide
echo ""

echo "💾 Storage:"
echo "-------------------"
echo "Storage Classes:"
kubectl get storageclass
echo ""
echo "Persistent Volume Claims:"
kubectl get pvc -A
echo ""
echo "Persistent Volumes:"
kubectl get pv
echo ""

echo "🌐 Services:"
echo "-------------------"
kubectl get svc -A
echo ""

echo "🔴 Pod Issues (if any):"
echo "-------------------"
kubectl get pods -A | grep -v Running | grep -v Completed || echo "✅ All pods are running!"
echo ""

echo "📝 Recent Events:"
echo "-------------------"
kubectl get events -A --sort-by='.lastTimestamp' | head -20
echo ""

echo "🎯 Application Status:"
echo "-------------------"
echo "Pi-hole:"
kubectl get pods -n pihole -o wide 2>/dev/null || echo "  Not deployed"

echo ""
echo "Home Assistant:"
kubectl get pods -n home -o wide 2>/dev/null || echo "  Not deployed"

echo ""
echo "N8n:"
kubectl get pods -n n8n -o wide 2>/dev/null || echo "  Not deployed"

echo ""
echo "Monitoring (Prometheus + Grafana):"
kubectl get pods -n monitoring -o wide 2>/dev/null || echo "  Not deployed"

echo ""
echo "======================================================================"
echo "🌐 Access URLs:"
echo "======================================================================"
echo ""
echo "Pi-hole:         http://10.0.0.100/admin"
echo "Home Assistant:  http://10.0.0.101:8123"
echo "N8n:             http://10.0.0.102:5678"
echo "Prometheus:      http://10.0.0.155:30090"
echo "Grafana:         http://10.0.0.155:30080"
echo ""
echo "======================================================================"
