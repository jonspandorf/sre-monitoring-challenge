#!/bin/bash

# Install Prometheus Operator using Helm
# This script installs the kube-prometheus-stack which includes:
# - Prometheus Operator
# - Prometheus
# - Grafana
# - Alertmanager
# - Node Exporter
# - Kube State Metrics

set -e

echo "🚀 Installing Prometheus Operator..."

# Add the Prometheus Community Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install the kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace promtheus \
  --create-namespace \
  --values values.yaml \
  --wait

echo "✅ Prometheus Operator installed successfully!"
echo ""
echo "📊 Access points:"
echo "  - Prometheus: kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090"
echo "  - Grafana: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "  - Grafana credentials: admin / prom-operator"
echo ""
echo "🔍 To check the status:"
echo "  kubectl get pods -n monitoring"
echo "  kubectl get servicemonitors -n monitoring" 