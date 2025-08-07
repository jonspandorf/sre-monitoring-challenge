#!/bin/bash

# Uninstall Prometheus Operator

set -e

echo "🗑️  Uninstalling Prometheus Operator..."

# Uninstall the kube-prometheus-stack
helm uninstall prometheus -n monitoring

# Optionally delete the namespace (uncomment if you want to remove everything)
# kubectl delete namespace monitoring

echo "✅ Prometheus Operator uninstalled successfully!" 