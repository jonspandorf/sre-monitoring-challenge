#!/bin/bash

# SRE Monitoring Challenge - Infrastructure Kickstart Script
# This script initializes all observability infrastructure on minikube

set -e  # Exit on any error

echo "🚀 Starting SRE Monitoring Challenge Infrastructure Setup..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if ! command -v minikube &> /dev/null; then
        print_error "minikube is not installed. Please install minikube first."
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        print_error "helm is not installed. Please install helm first."
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    print_success "All prerequisites are installed"
}

# Start minikube
start_minikube() {
    print_status "Starting minikube..."
    
    if minikube status | grep -q "Running"; then
        print_warning "Minikube is already running"
    else
        minikube start --memory=8192 --cpus=4 --disk-size=20g
        print_success "Minikube started successfully"
    fi
    
    print_success "Minikube started successfully"
}

# Add Elastic Helm repository
add_elastic_repo() {
    print_status "Adding Elastic Helm repository..."
    helm repo add elastic https://helm.elastic.co
    helm repo update
    print_success "Elastic Helm repository added and updated"
}

# Install Elasticsearch
install_elasticsearch() {
    print_status "Installing Elasticsearch..."
    cd obs_infra/elasticsearch
    
    helm install elasticsearch \
        --set replicas=1 \
        --set persistence.enabled=false \
        elastic/elasticsearch \
        -n obs \
        --create-namespace
    
    print_success "Elasticsearch installation initiated"
    cd ../..
}

# Install Prometheus
install_prometheus() {
    print_status "Installing Prometheus..."
    cd obs_infra/prometheus
    
    helm install prometheus -n obs .
    
    print_success "Prometheus installation initiated"
    cd ../..
}

# Install Jaeger
install_jaeger() {
    print_status "Installing Jaeger..."
    cd obs_infra/jaeger
    
#    helm dep up
    helm install jaeger -n obs .
    
    print_success "Jaeger installation initiated"
    cd ../..
}

# Install OpenTelemetry Collector
install_otel() {
    print_status "Installing OpenTelemetry Collector..."
    cd obs_infra/otel
    
        # helm dep up
    helm install otel -n obs .
    
    print_success "OpenTelemetry Collector installation initiated"
    cd ../..
}

# Install Elastic APM Server
install_elasticapm() {
    print_status "Installing Elastic APM Server..."
    cd obs_infra/elasticapm
    
    # helm dep up
    helm install apm-server -n obs .
    
    print_success "Elastic APM Server installation initiated"
    cd ../..
}

# Install Kibana
install_kibana() {
    print_status "Installing Kibana..."
    cd obs_infra/kibana

    encryption_key=$(/usr/bin/python3 -c "import random, string; print(''.join(random.choices(string.ascii_letters, k=32)))")

    kubectl -n obs create secret generic kibana-encryption-key --from-literal=encryptionKey=$encryption_key
    
    helm install kibana -f values.yaml elastic/kibana -n obs
    
    print_success "Kibana installation initiated"
    cd ../..
}


# Display service information
display_services() {
    print_status "Displaying service information..."
    
    echo ""
    echo "📊 Service Endpoints:"
    echo "===================="
    
    # Get minikube IP
    MINIKUBE_IP=$(minikube ip)
    
    echo "Minikube IP: $MINIKUBE_IP"
    echo ""
    
    # List services in obs namespace
    kubectl get services -n obs
    
    echo ""
    echo "🔍 To access services:"
    echo "====================="
    echo "Kibana:     kubectl port-forward -n obs svc/kibana-kibana 5601:5601"
    echo "Prometheus: kubectl port-forward -n obs svc/prometheus-server 9090:9090"
    echo "Jaeger:     kubectl port-forward -n obs svc/jaeger-query 16686:16686"
    echo "APM Server: kubectl port-forward -n obs svc/apm-server-apm-server 8200:8200"
    echo ""
    echo "📋 To check pod status:"
    echo "======================"
    echo "kubectl get pods -n obs"
    echo ""
    echo "📝 To view logs:"
    echo "==============="
    echo "kubectl logs -n obs <pod-name>"

}   



# Main execution
main() {
    echo "=========================================="
    echo "SRE Monitoring Challenge - Kickstart Script"
    echo "=========================================="
    echo ""
    
    check_prerequisites
    start_minikube
    # add_elastic_repo
    
    echo ""
    print_status "Installing observability infrastructure..."
    echo ""
    
    install_elasticsearch
    install_prometheus
    install_jaeger
    install_otel
    install_elasticapm
    install_kibana
    
    echo ""
    print_status "All Helm installations completed. Waiting for deployments to be ready..."
    echo ""

    echo ""
    print_success "🎉 Infrastructure setup completed successfully!"
    echo ""
    
    display_services
    
    echo ""
    echo "=========================================="
    echo "What to do next? 🤔"
    echo "1. Deploy the sample service..."
    echo "2. Go to Kibana and enable the APM server (APM -> adding the server -> set the host to apm-server-apm-server:8200 and also the same for http endpoint)"
    echo "3. Generate traffic using: ./scripts/generate-traffic.sh" 
    echo "=========================================="
}

# Run main function
main "$@"
