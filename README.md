# 🚀 SRE Monitoring Challenge - Solution

## 📖 Overview

This project demonstrates a comprehensive observability stack for the Flask-based application deployed in Kubernetes. The solution covers all three pillars of observability—metrics, logs, and traces—with a scalable architecture suitable for production environments.

## 🧠 Technology Stack & Rationale

| Pillar         | Technology                          | Justification                                                                                                                        |
| -------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| **Metrics**    | Prometheus + Grafana                 | Prometheus serves as the cloud-native standard for metrics collection, with the application instrumented using the Prometheus SDK. Grafana provides visualization capabilities for RED and USE metrics analysis. |
| **Logs**       | Elasticsearch + Kibana               | Elasticsearch offers scalable log aggregation and storage. Kibana enables powerful querying and visualization of structured JSON logs. |
| **Traces**     | OpenTelemetry + Elastic APM          | The application is instrumented with OpenTelemetry. Elastic APM serves as the agent to centralize traces, error analysis, and correlation with logs. While Jaeger was considered, Elastic APM provides a more robust and scalable solution. |
| **Dashboards** | Grafana, Kibana                      | Grafana visualizes infrastructure metrics (USE, RED patterns). Kibana complements this with application-level insights from APM and logs. |

## 💡 Alternative Technologies Considered

### Loki
- **Pros**: Lightweight, cost-effective log aggregation with native Grafana integration
- **Cons**: Less mature ecosystem compared to Elasticsearch, fewer advanced features

### Jaeger
- **Pros**: Industry-standard tracing solution with Grafana integration
- **Cons**: Elastic APM offers superior scalability and robustness, though some premium features require subscription

### Commercial APM Platforms (Coralogix, Datadog, Dynatrace)
- **Pros**: Comprehensive APM capabilities
- **Cons**: Cost-prohibitive for small-scale projects

## 🔧 Deployment Architecture

The observability stack is deployed in a dedicated monitoring namespace alongside the microservice in Minikube using Helm charts. Each component is modular, enabling isolated upgrades and maintenance. A kickstart script automates the entire setup process.

## 📊 Dashboards & Visualizations

### Available Dashboards
- **APM Dashboard**: Real-time application performance analytics by traces and logs
- **Grafana Dashboard**: Infrastructure and application metrics visualization. Provisioned automatically by the prometheus-grafana sidecar from `helm/templates/dashboard.yaml` configmap. 

## 🚨 Alerting Strategy

Alerts are defined in `helm/values.yaml` and templated `helm/templates/alerts.yaml`. The alerts based on the exposed application metrics. 

### RED Metrics (Application)
- **Error Rate**: Alert when error percentage exceeds threshold over 5-minute windows
- **Latency**: Alert on response time increases over 1-minute periods
- **Application Health**: Monitor application availability and health status

### USE Metrics (Infrastructure)
- **Resource Spikes**: Alert on CPU and RAM spikes lasting 5+ minutes
- **High Utilization**: Monitor sustained high CPU and RAM usage

## ⚙️ Environment Setup

### Quick Start
Execute the kickstart script located at `scripts/kickstart.sh` to:
- Initialize Minikube
- Deploy all observability components
- Launch the application

### Post-Deployment Steps
1. Deploy the application. `helm install sample-service -n monitoring --create-namespace ./helm`
2. Generate traffic using the provided scripts to obtain telemetry for at least 10 minutes `./scripts/generate-traffic.sh --port-forward 600`
3. Obtain the Elasticsearch password `kubectl get secrets -n obs elasticsearch-master-credentials -ojsonpath='{.data.password}' | base64 -d | pbcopy`
4. Access Kibana UI by port-forward `kubectl port-forward -n obs svc/kibana-kibana 5601`. Use `elastic` for username and paste the copied secret.
5. Go to APM and click on sample-service to observe the performance by traces and watch the transactions. 
6. Obtain the Grafana admin password `kubectl get secrets -n obs prometheus-grafana -ojsonpath='{.data.admin-password}' | base64 -d | pbcopy`
7. Access Grafana (choose your favorite http port) and select the sample-service dashboard from the buttom of dashboards `kubectl port-forward -n obs svc/prometheus-grafana 8085:80`
8. Observe the current state of the application by observing the application metrics and Pod resource usage.

## 📁 Project Structure

```
sre-monitoring-challenge/
├── app/                    # Flask application
├── helm/                   # Kubernetes deployment charts
├── obs_infra/             # Observability infrastructure charts
├── scripts/               # Automation scripts
├── terraform/             # Infrastructure as Code
└── README.md              # This file
```

