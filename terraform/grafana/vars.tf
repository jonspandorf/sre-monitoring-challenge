variable "GRAFANA_ADMIN_USER" {
  type        = string
  description = "Grafana admin user"
}

variable "GRAFANA_ADMIN_PASSWORD" {
  type        = string
  description = "Grafana admin password"
  sensitive   = true
}