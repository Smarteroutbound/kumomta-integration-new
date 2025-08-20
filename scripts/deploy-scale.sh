#!/bin/bash

# 🚀 KumoMTA Horizontal Scaling Deployment Script
# Deploys and manages multiple KumoMTA instances for high-volume email delivery

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="/var/log/kumomta/scale-deployment.log"
SCALE_CONFIG="$PROJECT_DIR/docker-compose.scale.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

# Error logging
error_log() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

# Success logging
success_log() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

# Warning logging
warning_log() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error_log "This script must be run as root"
        exit 1
    fi
}

# Check Docker availability
check_docker() {
    if ! command -v docker &> /dev/null; then
        error_log "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        error_log "Docker daemon is not running"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        error_log "Docker Compose is not installed or not in PATH"
        exit 1
    fi
}

# Check if scaling configuration exists
check_scale_config() {
    if [[ ! -f "$SCALE_CONFIG" ]]; then
        error_log "Scaling configuration not found: $SCALE_CONFIG"
        exit 1
    fi
    
    success_log "Scaling configuration found: $SCALE_CONFIG"
}

# Stop single-instance deployment
stop_single_instance() {
    log "Stopping single-instance deployment..."
    
    if [[ -f "$PROJECT_DIR/docker-compose.yml" ]]; then
        cd "$PROJECT_DIR"
        docker-compose down --remove-orphans
        success_log "Single-instance deployment stopped"
    else
        warning_log "Single-instance docker-compose.yml not found"
    fi
}

# Deploy scaled infrastructure
deploy_scaled_infrastructure() {
    log "Deploying scaled KumoMTA infrastructure..."
    
    cd "$PROJECT_DIR"
    
    # Start Redis cluster first
    log "Starting Redis cluster..."
    docker-compose -f "$SCALE_CONFIG" up -d redis
    
    # Wait for Redis to be healthy
    log "Waiting for Redis to be healthy..."
    local redis_healthy=0
    local attempts=0
    while [[ $redis_healthy -eq 0 && $attempts -lt 30 ]]; do
        if docker-compose -f "$SCALE_CONFIG" exec redis redis-cli ping &> /dev/null; then
            redis_healthy=1
            success_log "Redis is healthy"
        else
            attempts=$((attempts + 1))
            log "Waiting for Redis... (attempt $attempts/30)"
            sleep 10
        fi
    done
    
    if [[ $redis_healthy -eq 0 ]]; then
        error_log "Redis failed to become healthy after 30 attempts"
        exit 1
    fi
    
    # Start TSA daemon
    log "Starting TSA daemon..."
    docker-compose -f "$SCALE_CONFIG" up -d tsa-daemon
    
    # Wait for TSA to be healthy
    log "Waiting for TSA daemon to be healthy..."
    local tsa_healthy=0
    attempts=0
    while [[ $tsa_healthy -eq 0 && $attempts -lt 30 ]]; do
        if curl -f http://localhost:8008/health &> /dev/null; then
            tsa_healthy=1
            success_log "TSA daemon is healthy"
        else
            attempts=$((attempts + 1))
            log "Waiting for TSA daemon... (attempt $attempts/30)"
            sleep 10
        fi
    done
    
    if [[ $tsa_healthy -eq 0 ]]; then
        error_log "TSA daemon failed to become healthy after 30 attempts"
        exit 1
    fi
    
    # Start KumoMTA instances
    log "Starting KumoMTA instances..."
    docker-compose -f "$SCALE_CONFIG" up -d kumod-1 kumod-2 kumod-3
    
    # Wait for all instances to be healthy
    log "Waiting for KumoMTA instances to be healthy..."
    local all_healthy=0
    attempts=0
    while [[ $all_healthy -eq 0 && $attempts -lt 60 ]]; do
        local healthy_count=0
        for i in 1 2 3; do
            if curl -f "http://localhost:800$i/health" &> /dev/null; then
                healthy_count=$((healthy_count + 1))
            fi
        done
        
        if [[ $healthy_count -eq 3 ]]; then
            all_healthy=1
            success_log "All KumoMTA instances are healthy"
        else
            attempts=$((attempts + 1))
            log "Waiting for KumoMTA instances... (attempt $attempts/60) - $healthy_count/3 healthy"
            sleep 10
        fi
    done
    
    if [[ $all_healthy -eq 0 ]]; then
        error_log "KumoMTA instances failed to become healthy after 60 attempts"
        exit 1
    fi
    
    # Start monitoring stack
    log "Starting monitoring stack..."
    docker-compose -f "$SCALE_CONFIG" up -d prometheus grafana alertmanager node-exporter redis-exporter
    
    # Start load balancer
    log "Starting HAProxy load balancer..."
    docker-compose -f "$SCALE_CONFIG" up -d haproxy
    
    # Wait for load balancer to be healthy
    log "Waiting for HAProxy to be healthy..."
    local haproxy_healthy=0
    attempts=0
    while [[ $haproxy_healthy -eq 0 && $attempts -lt 30 ]]; do
        if curl -f http://localhost:8080/stats &> /dev/null; then
            haproxy_healthy=1
            success_log "HAProxy is healthy"
        else
            attempts=$((attempts + 1))
            log "Waiting for HAProxy... (attempt $attempts/30)"
            sleep 10
        fi
    done
    
    if [[ $haproxy_healthy -eq 0 ]]; then
        error_log "HAProxy failed to become healthy after 30 attempts"
        exit 1
    fi
    
    success_log "Scaled infrastructure deployment completed"
}

# Verify scaling deployment
verify_scaling() {
    log "Verifying scaled deployment..."
    
    # Check all services are running
    log "Checking service status..."
    docker-compose -f "$SCALE_CONFIG" ps
    
    # Test load balancer
    log "Testing load balancer..."
    for port in 25 587 8000; do
        if nc -z localhost $port; then
            success_log "Port $port is accessible through load balancer"
        else
            error_log "Port $port is not accessible through load balancer"
        fi
    done
    
    # Test individual instances
    log "Testing individual KumoMTA instances..."
    for i in 1 2 3; do
        if curl -f "http://localhost:800$i/health" &> /dev/null; then
            success_log "KumoMTA instance $i is healthy"
        else
            error_log "KumoMTA instance $i is not healthy"
        fi
    done
    
    # Test monitoring
    log "Testing monitoring stack..."
    if curl -f http://localhost:9090/-/healthy &> /dev/null; then
        success_log "Prometheus is healthy"
    else
        error_log "Prometheus is not healthy"
    fi
    
    if curl -f http://localhost:3000/api/health &> /dev/null; then
        success_log "Grafana is healthy"
    else
        error_log "Grafana is not healthy"
    fi
    
    if curl -f http://localhost:9093/-/healthy &> /dev/null; then
        success_log "Alertmanager is healthy"
    else
        error_log "Alertmanager is not healthy"
    fi
    
    # Test Redis cluster
    log "Testing Redis cluster..."
    if docker-compose -f "$SCALE_CONFIG" exec redis redis-cli ping &> /dev/null; then
        success_log "Redis cluster is healthy"
    else
        error_log "Redis cluster is not healthy"
    fi
    
    success_log "Scaling verification completed"
}

# Performance testing
run_performance_test() {
    log "Running performance test on scaled infrastructure..."
    
    # Test email delivery through load balancer
    log "Testing email delivery through load balancer..."
    
    # Send test emails through each port
    for port in 25 587; do
        log "Testing SMTP on port $port..."
        for i in {1..50}; do
            echo "Subject: Performance Test $i" | nc localhost $port &
        done
        wait
        
        success_log "Sent 50 test emails through port $port"
    done
    
    # Test HTTP API through load balancer
    log "Testing HTTP API through load balancer..."
    for i in {1..100}; do
        curl -s "http://localhost:8000/health" > /dev/null &
    done
    wait
    
    success_log "Sent 100 HTTP requests through load balancer"
    
    # Check load distribution
    log "Checking load distribution..."
    local haproxy_stats=$(curl -s "http://localhost:8080/stats;csv")
    
    # Parse stats to see request distribution
    echo "$haproxy_stats" | grep "kumod-" | while read line; do
        local server=$(echo "$line" | cut -d',' -f1)
        local requests=$(echo "$line" | cut -d',' -f8)
        log "Server $server: $requests requests"
    done
    
    success_log "Performance test completed"
}

# Generate scaling report
generate_scaling_report() {
    log "Generating scaling deployment report..."
    
    local report_file="$SCRIPT_DIR/scaling-report-$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# KumoMTA Horizontal Scaling Deployment Report

**Generated**: $(date)
**Configuration**: $SCALE_CONFIG

## Deployment Summary

### Services Deployed
- **Redis Cluster**: 1 instance with clustering enabled
- **KumoMTA Instances**: 3 instances (kumod-1, kumod-2, kumod-3)
- **TSA Daemon**: 1 instance with cluster mode
- **HAProxy Load Balancer**: 1 instance
- **Monitoring Stack**: Prometheus, Grafana, Alertmanager
- **Exporters**: Node Exporter, Redis Exporter

### Port Mappings
- **SMTP (25)**: Load balanced across 3 KumoMTA instances
- **SMTP Submission (587)**: Load balanced across 3 KumoMTA instances
- **HTTP API (8000)**: Load balanced across 3 KumoMTA instances
- **HAProxy Stats (8080)**: Load balancer statistics
- **Monitoring**: Prometheus (9090), Grafana (3000), Alertmanager (9093)

## Performance Characteristics

### Capacity Estimates
- **Email Throughput**: 3x single instance capacity
- **Concurrent Connections**: Up to 3,000 SMTP connections
- **Queue Processing**: 3x faster queue processing
- **Fault Tolerance**: Automatic failover between instances

### Resource Requirements
- **CPU**: 6 cores minimum (2 per instance)
- **Memory**: 12GB minimum (4GB per instance)
- **Storage**: 3x RocksDB storage requirements
- **Network**: High-bandwidth for load balancing

## Load Balancing Strategy

### Algorithm
- **SMTP Traffic**: Round-robin distribution
- **HTTP API**: Round-robin distribution
- **Health Checks**: Active health monitoring
- **Failover**: Automatic instance removal on failure

### Rate Limiting
- **Per-IP Limits**: 100 requests per 10 seconds
- **Global Limits**: Distributed across instances
- **Stick Tables**: Session persistence for SMTP

## Monitoring & Alerting

### Metrics Collection
- **Instance Metrics**: Individual KumoMTA performance
- **Load Balancer Metrics**: Traffic distribution and health
- **System Metrics**: Host resource utilization
- **Redis Metrics**: Cluster performance and memory

### Alerts
- **Instance Health**: Individual instance failures
- **Load Balancer Health**: HAProxy failures
- **Performance Degradation**: Response time increases
- **Capacity Issues**: Queue depth and throughput

## Maintenance Procedures

### Rolling Updates
1. Stop one instance
2. Update configuration
3. Restart instance
4. Verify health
5. Repeat for other instances

### Scaling Operations
- **Scale Up**: Add more KumoMTA instances
- **Scale Down**: Remove instances gracefully
- **Load Rebalancing**: Redistribute traffic

## Security Considerations

### Network Isolation
- **Internal Communication**: Docker network isolation
- **External Access**: Only through load balancer
- **Health Checks**: Internal health monitoring

### Access Control
- **HAProxy Stats**: Basic authentication required
- **API Access**: Rate limited and monitored
- **Logging**: Comprehensive audit logging

## Recommendations

### Immediate Actions
1. Monitor performance for 24 hours
2. Verify load distribution is even
3. Test failover scenarios
4. Review alert thresholds

### Long-term Planning
1. Implement auto-scaling based on metrics
2. Add geographic distribution
3. Implement advanced load balancing algorithms
4. Add SSL termination at load balancer

EOF

    success_log "Scaling report generated: $report_file"
}

# Main deployment function
main_deployment() {
    log "Starting KumoMTA horizontal scaling deployment..."
    
    # Check prerequisites
    check_root
    check_docker
    check_scale_config
    
    # Stop single instance
    stop_single_instance
    
    # Deploy scaled infrastructure
    deploy_scaled_infrastructure
    
    # Verify deployment
    verify_scaling
    
    # Run performance test
    run_performance_test
    
    # Generate report
    generate_scaling_report
    
    success_log "Horizontal scaling deployment completed successfully"
}

# Command line interface
case "${1:-}" in
    "deploy")
        main_deployment
        ;;
    "verify")
        check_docker
        check_scale_config
        verify_scaling
        ;;
    "test")
        check_docker
        check_scale_config
        run_performance_test
        ;;
    "report")
        generate_scaling_report
        ;;
    "stop")
        log "Stopping scaled infrastructure..."
        cd "$PROJECT_DIR"
        docker-compose -f "$SCALE_CONFIG" down --remove-orphans
        success_log "Scaled infrastructure stopped"
        ;;
    "start")
        log "Starting scaled infrastructure..."
        cd "$PROJECT_DIR"
        docker-compose -f "$SCALE_CONFIG" up -d
        success_log "Scaled infrastructure started"
        ;;
    "restart")
        log "Restarting scaled infrastructure..."
        cd "$PROJECT_DIR"
        docker-compose -f "$SCALE_CONFIG" restart
        success_log "Scaled infrastructure restarted"
        ;;
    "status")
        log "Checking scaled infrastructure status..."
        cd "$PROJECT_DIR"
        docker-compose -f "$SCALE_CONFIG" ps
        ;;
    "logs")
        local service="${2:-}"
        if [[ -n "$service" ]]; then
            log "Showing logs for $service..."
            cd "$PROJECT_DIR"
            docker-compose -f "$SCALE_CONFIG" logs -f "$service"
        else
            log "Showing all logs..."
            cd "$PROJECT_DIR"
            docker-compose -f "$SCALE_CONFIG" logs -f
        fi
        ;;
    "help"|"--help"|"-h")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  deploy   - Deploy horizontal scaling (default)"
        echo "  verify   - Verify scaled deployment"
        echo "  test     - Run performance tests"
        echo "  report   - Generate scaling report"
        echo "  stop     - Stop scaled infrastructure"
        echo "  start    - Start scaled infrastructure"
        echo "  restart  - Restart scaled infrastructure"
        echo "  status   - Show service status"
        echo "  logs     - Show service logs (optionally specify service)"
        echo "  help     - Show this help message"
        ;;
    *)
        main_deployment
        ;;
esac
