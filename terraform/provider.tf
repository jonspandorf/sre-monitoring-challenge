terraform {
  required_providers {
    elasticstack = {
      source = "elastic/elasticstack"
      version = "0.11.17"
    }
  }
}

provider "elasticstack" {
  kibana {
    # Kibana connection configuration
    # For local development with minikube, you might use:
    endpoints = ["http://kibana-kibana:5601"]
    username = var.ES_USERNAME
    password = var.ES_PASSWORD
  }
}
