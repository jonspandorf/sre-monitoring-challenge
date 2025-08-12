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

# Function to check helm release status and handle existing installations
check_and_install_helm() {
    local release_name=$1
    local chart_path=$2
    local chart_repo=$3
    local chart_name=$4
    local additional_args=$5
    
    print_status "Checking $release_name installation status..."
    
    if helm list -n obs | grep -q "^$release_name"; then
        print_warning "$release_name is already installed. Checking status..."
        
        # Check if the release is in a failed or pending state
        local status=$(helm status $release_name -n obs --output json 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
        
        if [[ "$status" == "deployed" ]]; then
            print_success "$release_name is already running successfully. Skipping installation."
            return 0
        else
            print_warning "$release_name is in '$status' state. Uninstalling and reinstalling..."
            helm uninstall $release_name -n obs
            # Wait a bit for cleanup
            sleep 5
        fi
    fi
    
    print_status "Installing $release_name..."
    
    if [[ -n "$chart_repo" && -n "$chart_name" ]]; then
        # External chart installation
        helm install $release_name $chart_repo/$chart_name $additional_args -n obs
    else
        # Local chart installation
        helm install $release_name -n obs . $additional_args
    fi
    
    print_success "$release_name installation initiated"
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

# Ensure obs namespace exists
ensure_namespace() {
    print_status "Ensuring obs namespace exists..."
    kubectl create namespace obs --dry-run=client -o yaml | kubectl apply -f -
    print_success "Namespace 'obs' is ready"
}

# Add Elastic Helm repository
add_elastic_repo() {
    print_status "Adding Elastic Helm repository..."
    helm repo add elastic https://helm.elastic.co
    helm repo update
    print_success "Elastic Helm repository added and updated"
}

add_prometheus_repo() {
    print_status "Adding Prometheus Helm repository..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update
    print_success "Prometheus Helm repository added and updated"
}

add_otel_repo() {
    print_status "Adding OpenTelemetry Helm repository..."
    helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
    helm repo update
    print_success "OpenTelemetry Helm repository added and updated"
}

# Install Elasticsearch
install_elasticsearch() {
    print_status "Installing Elasticsearch..."
    cd obs_infra/elasticsearch
    
    check_and_install_helm "elasticsearch" "." "elastic" "elasticsearch" "--set replicas=1 --set persistence.enabled=false"
    
    cd ../..
}

# Install Prometheus
install_prometheus() {
    print_status "Installing Prometheus..."
    cd obs_infra/prometheus
    
    helm dep up
    check_and_install_helm "prometheus" "." "" "" ""
    
    cd ../..
}

# Install Jaeger
install_jaeger() {
    print_status "Installing Jaeger..."
    cd obs_infra/jaeger
    
    helm dep up
    check_and_install_helm "jaeger" "." "" "" ""
    
    cd ../..
}

# Install OpenTelemetry Collector
install_otel() {
    print_status "Installing OpenTelemetry Collector..."
    cd obs_infra/otel
    
    helm dep up
    check_and_install_helm "otel" "." "" "" ""
    
    cd ../..
}

# Install Elastic APM Server
install_elasticapm() {
    print_status "Installing Elastic APM Server..."
    cd obs_infra/elasticapm
    
    helm dep up
    check_and_install_helm "apm-server" "." "" "" ""
    
    cd ../..
}

# Install Kibana
install_kibana() {
    print_status "Installing Kibana..."
    cd obs_infra/kibana

    encryption_key=$(/usr/bin/python3 -c "import random, string; print(''.join(random.choices(string.ascii_letters, k=32)))")

    kubectl -n obs create secret generic kibana-encryption-key --from-literal=encryptionKey=$encryption_key --dry-run=client -o yaml | kubectl apply -f -
    
    check_and_install_helm "kibana" "." "elastic" "kibana" "-f values.yaml"
    
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
    ensure_namespace
    add_elastic_repo
    add_prometheus_repo
    add_otel_repo
    echo ""
    print_status "Installing observability infrastructure..."
    echo ""
    
    install_elasticsearch
    install_prometheus
#    install_jaeger
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
    echo "1. Deploy the sample service... (helm install sample-service -n monitoring --create-namespace ./helm --wait)"
    echo "2. Genetrate traffic for at least 10 minutes (./scripts/generate-traffic.sh --port-forward 600)" 
    echo "3. Obtain the Elasticsearch password (kubectl get secrets -n obs elasticsearch-master-credentials -ojsonpath='{.data.password}' | base64 -d | pbcopy)"
    echo "4. Access Kibana UI by port-forward (kubectl port-forward -n obs svc/kibana-kibana 5601)"
    echo "5. Use `elastic` for username and paste the copied secret."
    echo "6. Go to APM and click on sample-service to observe the performance by traces and watch the transactions." 
    echo "7. Obtain the Grafana admin password (kubectl get secrets -n obs prometheus-grafana -ojsonpath='{.data.admin-password}' | base64 -d | pbcopy)"
    echo "8. Access Grafana and select the sample-service dashboard from the buttom of dashboards (kubectl port-forward -n obs svc/prometheus-grafana 8085:80)"
    echo "9. Observe the current state of the application by observing the application metrics and Pod resource usage."
    echo "=========================================="
}

# Run main function
main "$@"
