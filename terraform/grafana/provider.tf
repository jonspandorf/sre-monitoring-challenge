terraform {
  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = "1.0.0"
    }
  }
}

provider "grafana" {
  url  = "http://prometheus-grafana"
  auth = "${var.GRAFANA_ADMIN_USER}:${var.GRAFANA_ADMIN_PASSWORD}"
}

