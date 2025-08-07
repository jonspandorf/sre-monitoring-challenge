# 🚀 SRE Monitoring Challenge - Solution

## 📖 Overview

This project demonstrates a comprehensive observability stack for the Flask-based application deployed in Kubernetes. The solution covers all three pillars of observability—metrics, logs, and traces—with a scalable architecture suitable for production environments.

## 🧠 Technology Stack & Rationale

| Pillar         | Technology                          | Justification                                                                                                                        |
| -------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| **Metrics**    | Prometheus + Grafana                 | Prometheus serves as the cloud-native standard for metrics collection, with the application instrumented using the Prometheus SDK. Grafana provides visualization capabilities for RED and USE metrics analysis. |
| **Logs**       | Elasticsearch + Kibana               | Elasticsearch offers scalable log aggregation and storage. Kibana enables powerful querying and visualization of structured JSON logs. |
| **Traces**     | OpenTelemetry + Elastic APM          | The application is instrumented with OpenTelemetry. Elastic APM serves as the backend to centralize traces, error analysis, and correlation with logs. While Jaeger was considered, Elastic APM provides a more robust and scalable solution. |
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

### Setup Instructions
1. **Kibana APM Integration**: Navigate to APM → Add Integration → Configure with `apm-server-apm-server:8200`
2. **Grafana Dashboard**: Import the provided dashboard to visualize metrics when traffic is generated
3. **Jaeger Integration**: Add Jaeger as a data source in Grafana and connect to `http://jaeger-query`

### Available Dashboards
- **APM Dashboard**: Real-time application performance analytics
- **Grafana Dashboard**: Infrastructure and application metrics visualization

## 🚨 Alerting Strategy

While not implemented in this solution, the recommended approach uses Terraform to provision alerts in both Kibana and Grafana. The alerting strategy focuses on:

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
1. Access Kibana UI and enable APM integration
2. Access Grafana and import the dashboard
3. Generate traffic using the provided scripts to observe metrics

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

