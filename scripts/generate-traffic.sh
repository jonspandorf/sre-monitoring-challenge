#!/bin/bash

# 🎯 Sample Service Traffic Generator
# Generates realistic HTTP traffic patterns for monitoring demonstrations
# Assumes the service is accessible at http://localhost:8080

set -e

# Configuration
SERVICE_URL="http://localhost:8080"
SERVICE_NAME="sample-service"
NAMESPACE="monitoring"
PORTFORWARD_PID=""
USE_PORTFORWARD=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if port is in use
check_port() {
    local port=$1
    if lsof -i ":$port" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Setup port-forward if requested
setup_port_forward() {
    if [ "$USE_PORTFORWARD" = true ]; then
        log "Setting up port-forward..."

        # Check if service exists
        if ! kubectl get svc "$SERVICE_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
            error "Service '$SERVICE_NAME' not found in namespace '$NAMESPACE'"
            error "Please deploy the service first:"
            error "  helm install sample-service ./helm -n monitoring --create-namespace"
            exit 1
        fi

        # Check if port 8080 is already in use
        if check_port 8080; then
            error "Port 8080 is already in use. Please free it first or run without --port-forward"
            exit 1
        fi

        log "Starting port-forward for sample service..."
        kubectl port-forward -n "$NAMESPACE" "svc/$SERVICE_NAME" 8080:80 >/dev/null 2>&1 &
        PORTFORWARD_PID=$!
        sleep 3

        if ! check_port 8080; then
            error "Failed to establish port-forward to sample service"
            exit 1
        fi

        log "✅ Port-forward established: localhost:8080 -> $SERVICE_NAME:80"
    fi
}

# Cleanup port-forward on exit
cleanup() {
    if [ -n "$PORTFORWARD_PID" ] && kill -0 "$PORTFORWARD_PID" 2>/dev/null; then
        log "Cleaning up port-forward..."
        kill "$PORTFORWARD_PID" 2>/dev/null || true
    fi
}

# Test service accessibility
test_service() {
    log "Testing service connectivity at $SERVICE_URL..."
    if curl -s --connect-timeout 5 --max-time 10 "$SERVICE_URL/health" >/dev/null; then
        success "✅ Sample service accessible at $SERVICE_URL"
    else
        error "❌ Cannot reach sample service at $SERVICE_URL"
        if [ "$USE_PORTFORWARD" = true ]; then
            error "Port-forward was set up but service is not responding"
            error "Please check that the service is running properly"
        else
            error "Please ensure:"
            error "  1. Service is deployed: helm install sample-service ./helm -n monitoring --create-namespace"
            error "  2. Port-forward is active: kubectl port-forward -n monitoring svc/sample-service 8080:80"
            error "     OR use: $0 --port-forward [duration] to handle port-forward automatically"
        fi
        exit 1
    fi
}

# Make HTTP request and return status code
make_request() {
    local endpoint=$1
    local timeout=${2:-10}
    curl -s -w "%{http_code}" --connect-timeout 3 --max-time "$timeout" "$endpoint" -o /dev/null 2>/dev/null || echo "000"
}

# Generate normal traffic
generate_normal_traffic() {
    local duration=$1
    local end_time=$(($(date +%s) + duration))
    
    echo
    log "👤 Normal Traffic Pattern (${duration}s)"
    echo "   📊 Mix: 60% /api/users, 20% /api/users/{id}, 10% /health, 10% /api/slow"
    echo
    
    local count=0
    local success=0
    local errors=0
    
    while [ $(date +%s) -lt $end_time ]; do
        ((count++))
        
        # Choose endpoint based on realistic distribution
        case $((RANDOM % 10)) in
            0|1|2|3|4|5)  # 60% - Normal API usage
                local code=$(make_request "$SERVICE_URL/api/users" 10)
                printf "   %2d. GET /api/users" "$count"
                ;;
            6|7)  # 20% - Individual user requests
                local user_id=$((RANDOM % 10 + 1))
                local code=$(make_request "$SERVICE_URL/api/users/$user_id" 10)
                printf "   %2d. GET /api/users/%d" "$count" "$user_id"
                ;;
            8)  # 10% - Health checks
                local code=$(make_request "$SERVICE_URL/health" 10)
                printf "   %2d. GET /health" "$count"
                ;;
            9)  # 10% - Slow endpoints
                local code=$(make_request "$SERVICE_URL/api/slow" 15)
                printf "   %2d. GET /api/slow" "$count"
                ;;
        esac
        
        # Show status
        if [[ "$code" =~ ^2 ]]; then
            echo " ✅ $code"
            ((success++))
        elif [[ "$code" =~ ^4 ]]; then
            echo " ⚠️ $code"
            ((errors++))
        elif [[ "$code" =~ ^5 ]]; then
            echo " ❌ $code"
            ((errors++))
        else
            echo " 💥 timeout"
            ((errors++))
        fi
        
        sleep $((RANDOM % 2 + 1))
    done
    
    success "Normal traffic completed: $count requests (✅ $success success, ❌ $errors errors)"
}

# Generate traffic spike
generate_traffic_spike() {
    echo
    log "📈 Traffic Spike (15 rapid requests)"
    echo
    
    local success=0
    local errors=0
    
    for i in {1..15}; do
        # Rapid requests to multiple endpoints
        local code1=$(make_request "$SERVICE_URL/api/users" 5)
        local code2=$(make_request "$SERVICE_URL/health" 5)
        
        printf "   Burst %2d: GET /api/users" "$i"
        if [[ "$code1" =~ ^2 ]]; then
            echo -n " ✅$code1"
            ((success++))
        else
            echo -n " ❌$code1"
            ((errors++))
        fi
        
        echo -n ", GET /health"
        if [[ "$code2" =~ ^2 ]]; then
            echo " ✅$code2"
            ((success++))
        else
            echo " ❌$code2"
            ((errors++))
        fi
        
        sleep 0.5
    done
    
    success "Traffic spike completed: 30 requests (✅ $success success, ❌ $errors errors)"
}

# Generate error burst
generate_error_burst() {
    echo
    log "💥 Error Burst (testing error handling)"
    echo
    
    local success=0
    local errors=0
    
    for i in {1..10}; do
        local code=$(make_request "$SERVICE_URL/api/flaky" 5)
        printf "   %2d. GET /api/flaky" "$i"
        
        if [[ "$code" =~ ^2 ]]; then
            echo " ✅ $code"
            ((success++))
        elif [[ "$code" =~ ^5 ]]; then
            echo " ❌ $code"
            ((errors++))
        else
            echo " ⚠️ $code"
            ((errors++))
        fi
        
        sleep 0.8
    done
    
    success "Error burst completed: 10 requests (✅ $success success, ❌ $errors errors)"
}

# Generate performance test
generate_performance_test() {
    echo
    log "🐌 Performance Test (slow endpoints)"
    echo
    
    local total_time=0
    local success=0
    local errors=0
    
    for i in {1..5}; do
        printf "   %d. GET /api/slow ... " "$i"
        
        local start_time=$(date +%s)
        local code=$(make_request "$SERVICE_URL/api/slow" 15)
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        total_time=$((total_time + duration))
        
        if [[ "$code" =~ ^2 ]]; then
            echo "✅ $code (${duration}s)"
            ((success++))
        else
            echo "❌ $code (${duration}s)"
            ((errors++))
        fi
        
        sleep 1
    done
    
    local avg_time=$((total_time / 5))
    success "Performance test completed: 5 requests (✅ $success success, ❌ $errors errors, avg ${avg_time}s)"
}

# Display metrics summary
show_metrics_summary() {
    echo
    log "📊 Current metrics summary"
    
    if curl -s --connect-timeout 5 --max-time 10 "$SERVICE_URL/metrics" | grep -q "sample_service"; then
        echo
        echo "📈 Request Counts:"
        curl -s "$SERVICE_URL/metrics" | grep "sample_service_requests_total" | head -5
        echo
        echo "🟢 Service Status:"
        curl -s "$SERVICE_URL/metrics" | grep "sample_service_up"
    else
        error "Unable to fetch metrics from $SERVICE_URL/metrics"
    fi
}

# Main traffic generation
run_traffic_simulation() {
    local duration=$1
    
    echo
    log "🚀 Starting traffic simulation for ${duration} seconds"
    echo "   🎯 Target: $SERVICE_URL"
    echo "   📋 Patterns: Normal → Spike → Errors → Performance"
    
    # Calculate timing
    local normal_duration=$((duration * 60 / 100))      # 60% for normal traffic
    
    # Run traffic patterns sequentially
    generate_normal_traffic $normal_duration
    generate_traffic_spike
    generate_error_burst
    generate_performance_test
    
    echo
    success "🎉 Traffic simulation completed!"
    
    # Show final metrics
    show_metrics_summary
}

# Print usage
usage() {
    cat << EOF
🚀 Sample Service Traffic Generator

DESCRIPTION:
    Generates realistic HTTP traffic patterns for monitoring demonstrations.
    By default assumes the sample service is accessible at http://localhost:8080

USAGE:
    $0 [OPTIONS] [DURATION]

OPTIONS:
    -p, --port-forward   Automatically set up kubectl port-forward (optional)
    -h, --help          Show this help message

PARAMETERS:
    DURATION            Traffic duration in seconds (default: 60)

EXAMPLES:
    # Manual port-forward (default behavior)
    kubectl port-forward -n monitoring svc/sample-service 8080:80 &
    $0 60               # Run for 60 seconds

    # Automatic port-forward
    $0 --port-forward 120        # Run for 2 minutes with auto port-forward
    $0 -p 300                    # Run for 5 minutes with auto port-forward

PREREQUISITES:
    1. Deploy the service:
       helm install sample-service ./helm -n monitoring --create-namespace
    
    2a. Manual port-forward:
        kubectl port-forward -n monitoring svc/sample-service 8080:80
    
    2b. OR use automatic port-forward:
        $0 --port-forward [duration]

PATTERNS:
    🔄 Normal traffic (60% of time): Mixed realistic API calls
    📈 Traffic spike: 15 rapid concurrent requests
    💥 Error burst: 10 requests to error-prone endpoint
    🐌 Performance test: 5 slow requests with timing

MONITORING:
    📊 Before and after metrics comparison
    🎯 Rich telemetry data for dashboard testing
    🔍 Multiple HTTP status codes and response times
EOF
}

# Main execution
main() {
    local duration=60
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--port-forward)
                USE_PORTFORWARD=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            [0-9]*)
                duration=$1
                shift
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate duration
    if ! [[ "$duration" =~ ^[0-9]+$ ]] || [ "$duration" -lt 10 ]; then
        error "Duration must be a number >= 10 seconds"
        usage
        exit 1
    fi
    
    # Show header
    echo "🎯 Sample Service Traffic Generator Starting..."
    if [ "$USE_PORTFORWARD" = true ]; then
        log "Using automatic port-forward mode"
    fi
    
    # Setup port-forward if requested
    setup_port_forward
    
    # Test connectivity and show initial metrics
    test_service
    show_metrics_summary
    
    # Run simulation
    run_traffic_simulation $duration
    
    echo
    log "💡 Monitor your observability solution to see how it captured this traffic"
    log "🔍 Check your dashboards, alerts, and logs for the patterns generated"
}

# Set up cleanup on exit
trap cleanup EXIT

# Run main function with all arguments
main "$@"