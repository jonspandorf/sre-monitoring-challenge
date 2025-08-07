# 🚀 SRE Monitoring Challenge - Suggested Solution

## 📖 Introduction

This project demonstrates a complete observability stack for the Flask-based application deployed in Kubernetes. My goal was to cover all three pillars of observability—metrics, logs, traces, and suggest alerting—in a way that would scale in a real production environment.

## 🧠 Tooling Choices & Rationale

| Pillar         | Tool(s) Used                         | Justification                                                                                                                        |
| -------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| **Metrics**    | Prometheus + Grafana                 | Promtehus is the cloud native standard for scrape metrics and the application is instrumented with promehteus sdk. I use Grafana to      |
visualize the metric data given the RED and USE nature  |       
of the platform.                                        |
| **Logs**       | ElasticSearch + Kibana               | Elastic provides scalable log aggregation. Kibana enables powerful querying and visualization of structured JSON logs.                  |
| **Traces**     | OpenTelemetry + Elastic APM          | The app was instrumented with OTEL. I used Elastic APM as a backend to centralize traces, error breakdowns, and correlate with logs.      |
I considered Jaeger as well but Elastic APM offered a   |
more robust and scalable solution                       |
| **Dashboards** | Grafana, Kibana                      | Grafana was used to visualize infra metrics (USE, RED). Kibana complements this with app-level insights from APM and logs.                   |


## 💿 Optional techstack that was considered

# Loki - easily integrated with Grafana which allows to visualize log data. However, it does not provide the actual output and not as robust as Kibana. 

# Jaeger - it is the first solution for traces and can be integrated with Grafan as a data source. Elastic APM offered a more robust and scalable solution. However, Elastic APM still is not integrated with metrics and there some premium features that requries subscription.

# Coralogix, Datadog, Dyntrace all offeres a robust APM platform but one should evaluate the costs for the usage and it doesn't fit this type of small project. 

## 🔧 Deployment Architecture

I deployed the observability stack in one namespace alongside the microservice (in the monitoring namespace) in Minikube using Helm and provided a kickstart script to automate the setup. Each observability component is modular, allowing for isolated upgrades.

📈 Dashboards & Visualizations

After the deployment, enable the APM integration in Kibana (APM -> Add Integration -> add [apm-server-apm-server:8200,http://apm-server-apm-server:8200]). Imidieatly after you can observe the analytics in the APM Dashboard. 

You can import the Grafana dashboard and observe the metrics when traffic is generated. For Jaeger traces add the Jaeger datasource and connect to ```http://jaeger-query``` 


## 🚨 Alerts

I did not provision alerts though would use Terraform to provision them in both Kibana and Grafana. I would seperate the RED and USE and focus on the following:
*Error Rate Exceeded: how many errors occured during the last 5m (by percent or count)*
*Latency, if duration or response increases during 1m for example*
*Application is not healthy*
*Increased Spikes in CPU and RAM for at least 5m*
*High utilization of CPU and RAM*


## ⚙️ Init Environment

A kickstrt script can be found at `scripts/kickstart.sh` and spins minikube, the observability instances and the application. You would then have to access the Kibana UI and enable APM Integration. You can also access Grafana and add the dashboard. 

