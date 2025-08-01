# 🚀 SRE Monitoring Challenge

## 📖 Overview

Build a complete observability solution for this microservice. Demonstrate your SRE expertise by designing the monitoring infrastructure you think this service needs in production.

## 🎯 Your Mission

You've been given responsibility for observability of a production-like service running in Kubernetes. Your goal is to ensure it's observable—covering metrics, logging, dashboards, and alerting.

### Your Task:
Design and implement an observability solution for a sample microservice deployed on Kubernetes using Helm.

### You decide:
- What observability stack/tools to use
- How to deploy them (infra considerations, modularity, scalability)
- What metrics/logs/traces are important
- What alerts should be defined and why

**Show us your thinking!** We're interested in your approach, reasoning, and the choices you make.

## 📱 The Application

### What's provided:
- **Python Flask API** with realistic endpoints
- **Full instrumentation**: metrics, structured logs, and distributed traces
- **Kubernetes deployment** via Helm chart
- **Traffic generator** for testing your solution

### Available telemetry:
- **HTTP metrics** (request counts, durations, error rates)
- **Application metrics** (business logic, custom counters, operation types)
- **Structured JSON logs** with correlation IDs and trace correlation
- **Distributed traces** via OpenTelemetry (configure your endpoint)
- **Health checks** and readiness probes

## 🚀 Quick Start

```bash
# Deploy the service
helm install sample-service ./helm --namespace monitoring --create-namespace --wait

# Verify it's running
kubectl get pods -n monitoring
kubectl port-forward -n monitoring svc/sample-service 8080:80

# Test the service
curl http://localhost:8080/health        # Health check
curl http://localhost:8080/metrics       # Prometheus metrics
curl http://localhost:8080/api/users     # Normal API endpoint
curl http://localhost:8080/api/error     # Always returns 500 error
curl http://localhost:8080/api/flaky     # 30% chance of error
curl http://localhost:8080/api/slow      # 2-5 second response
```

## 🌊 Generate Traffic *(Optional)*

We've created a traffic generator script to help you test your monitoring solution with realistic usage patterns. This script simulates real-world traffic scenarios including normal operations, traffic spikes, error conditions, and performance issues - perfect for validating your observability setup.

### What patterns are generated:
- **Normal API usage** (60% of duration): `/api/users`, `/api/users/{id}`, `/health`
- **Traffic spike**: 30 rapid requests (fixed, regardless of duration)
- **Error testing**: 10 requests to `/api/flaky` (fixed, ~30% failure rate)
- **Performance testing**: 5 slow requests (fixed, 2-5s each)

### How to use:
```bash
# Option 1: Manual port-forward
kubectl port-forward -n monitoring svc/sample-service 8080:80 &
./scripts/generate-traffic.sh 60      # 1 minute of traffic

# Option 2: Automatic port-forward 
./scripts/generate-traffic.sh --port-forward 300     # 5 minutes

# Get help
./scripts/generate-traffic.sh --help
```

## 📁 Project Structure

```
sre-monitoring-challenge/
├── helm/                     # Kubernetes deployment
│   ├── Chart.yaml           # Helm chart
│   ├── values.yaml          # Configuration
│   └── templates/           # K8s manifests
│       ├── deployment.yaml  # Pod deployment
│       └── service.yaml     # Service definition
├── app/                     # Application code
│   ├── app.py              # Flask app with instrumentation
│   └── requirements.txt     # Dependencies
├── scripts/                 # Utilities
│   └── generate-traffic.sh  # Traffic generator
├── Dockerfile              # Container definition
└── README.md              # This file
```

## 🛠️ Build Your Solution

**Now it's up to you!** 

Design and implement the observability infrastructure you think this service needs. Consider what you'd want to monitor, alert on, and visualize if this were running in production.

---

**Good luck! 🎉**
