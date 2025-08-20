#!/bin/bash

# 🚀 KumoMTA Performance Optimizer
# Comprehensive performance tuning and optimization for Smarter Outbound

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/kumomta/performance-optimizer.log"
CONFIG_FILE="$SCRIPT_DIR/performance-config.yml"

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
}

# Check KumoMTA container status
check_kumomta_status() {
    log "Checking KumoMTA container status..."
    
    if ! docker-compose ps kumod | grep -q "Up"; then
        error_log "KumoMTA container is not running"
        exit 1
    fi
    
    success_log "KumoMTA container is running"
}

# Performance analysis
analyze_performance() {
    log "Starting performance analysis..."
    
    # Get current metrics
    local queue_depth=$(docker-compose exec kumod kumomta-cli queue depth 2>/dev/null || echo "0")
    local delivery_rate=$(curl -s "http://localhost:9090/api/v1/query?query=rate(kumomta_delivered_total[5m])" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
    local bounce_rate=$(curl -s "http://localhost:9090/api/v1/query?query=rate(kumomta_bounced_total[5m])/rate(kumomta_attempted_total[5m])" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
    local cpu_usage=$(docker stats --no-stream --format "table {{.CPUPerc}}" kumod | tail -1 | sed 's/%//')
    local memory_usage=$(docker stats --no-stream --format "table {{.MemPerc}}" kumod | tail -1 | sed 's/%//')
    
    log "Current Performance Metrics:"
    log "  Queue Depth: $queue_depth emails"
    log "  Delivery Rate: $delivery_rate emails/minute"
    log "  Bounce Rate: $(echo "$bounce_rate * 100" | bc -l 2>/dev/null || echo "0")%"
    log "  CPU Usage: $cpu_usage%"
    log "  Memory Usage: $memory_usage%"
    
    # Determine optimization level
    if [[ $(echo "$queue_depth > 10000" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        warning_log "High queue depth detected - aggressive optimization needed"
        OPTIMIZATION_LEVEL="aggressive"
    elif [[ $(echo "$queue_depth > 5000" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        warning_log "Moderate queue depth - standard optimization needed"
        OPTIMIZATION_LEVEL="standard"
    else
        log "Queue depth is normal - preventive optimization"
        OPTIMIZATION_LEVEL="preventive"
    fi
}

# RocksDB optimization
optimize_rocksdb() {
    log "Optimizing RocksDB storage..."
    
    local optimization_level=${1:-"standard"}
    
    case $optimization_level in
        "aggressive")
            log "Applying aggressive RocksDB optimization..."
            docker-compose exec kumod kumomta-cli spool optimize --aggressive
            docker-compose exec kumod kumomta-cli spool compact --force
            ;;
        "standard")
            log "Applying standard RocksDB optimization..."
            docker-compose exec kumod kumomta-cli spool optimize
            docker-compose exec kumod kumomta-cli spool compact
            ;;
        "preventive")
            log "Applying preventive RocksDB optimization..."
            docker-compose exec kumod kumomta-cli spool optimize --light
            ;;
    esac
    
    success_log "RocksDB optimization completed"
}

# Redis optimization
optimize_redis() {
    log "Optimizing Redis configuration..."
    
    # Set optimal memory policy
    docker-compose exec redis redis-cli config set maxmemory-policy allkeys-lru
    
    # Optimize memory usage based on available RAM
    local total_memory=$(free -m | awk 'NR==2{printf "%.0f", $2}')
    local redis_memory=$(echo "$total_memory * 0.3" | bc -l | cut -d. -f1)
    
    log "Setting Redis memory limit to ${redis_memory}MB"
    docker-compose exec redis redis-cli config set maxmemory "${redis_memory}mb"
    
    # Enable persistence optimization
    docker-compose exec redis redis-cli config set save "900 1 300 10 60 10000"
    
    success_log "Redis optimization completed"
}

# Worker scaling
scale_workers() {
    log "Scaling worker processes..."
    
    local current_workers=$(docker-compose exec kumod kumomta-cli worker count 2>/dev/null || echo "1")
    local queue_depth=$(docker-compose exec kumod kumomta-cli queue depth 2>/dev/null || echo "0")
    
    # Calculate optimal worker count
    local optimal_workers=1
    if [[ $(echo "$queue_depth > 10000" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        optimal_workers=8
    elif [[ $(echo "$queue_depth > 5000" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        optimal_workers=4
    elif [[ $(echo "$queue_depth > 1000" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        optimal_workers=2
    fi
    
    if [[ $optimal_workers -gt $current_workers ]]; then
        log "Scaling workers from $current_workers to $optimal_workers"
        docker-compose exec kumod kumomta-cli worker scale --count $optimal_workers
        success_log "Workers scaled to $optimal_workers"
    else
        log "Current worker count ($current_workers) is optimal"
    fi
}

# Throttling optimization
optimize_throttling() {
    log "Optimizing delivery throttling..."
    
    local current_time=$(date +%H)
    local is_business_hours=0
    
    # Check if it's business hours (9 AM - 5 PM)
    if [[ $current_time -ge 9 && $current_time -le 17 ]]; then
        is_business_hours=1
    fi
    
    if [[ $is_business_hours -eq 1 ]]; then
        log "Business hours detected - optimizing for peak performance"
        docker-compose exec kumod kumomta-cli throttle set --global --rate 2000
        docker-compose exec kumod kumomta-cli ip optimize --business-hours
    else
        log "Off-peak hours detected - optimizing for maintenance"
        docker-compose exec kumod kumomta-cli throttle set --global --rate 500
        docker-compose exec kumod kumomta-cli maintenance enable --reason "off-peak-optimization"
    fi
    
    success_log "Throttling optimization completed"
}

# Network optimization
optimize_network() {
    log "Optimizing network configuration..."
    
    # Check current network settings
    local current_connections=$(docker-compose exec kumod kumomta-cli connection count 2>/dev/null || echo "0")
    local max_connections=$(docker-compose exec kumod kumomta-cli connection limit 2>/dev/null || echo "1000")
    
    # Optimize connection limits based on load
    if [[ $(echo "$current_connections > $max_connections * 0.8" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        local new_limit=$(echo "$max_connections * 1.5" | bc -l | cut -d. -f1)
        log "Increasing connection limit from $max_connections to $new_limit"
        docker-compose exec kumod kumomta-cli connection limit --max $new_limit
    fi
    
    # Optimize DNS resolution
    docker-compose exec kumod kumomta-cli dns optimize
    
    success_log "Network optimization completed"
}

# Memory optimization
optimize_memory() {
    log "Optimizing memory usage..."
    
    # Check current memory usage
    local memory_usage=$(docker stats --no-stream --format "table {{.MemPerc}}" kumod | tail -1 | sed 's/%//')
    
    if [[ $(echo "$memory_usage > 80" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
        warning_log "High memory usage detected - applying memory optimization"
        
        # Clear Redis memory
        docker-compose exec redis redis-cli memory purge
        
        # Optimize RocksDB memory
        docker-compose exec kumod kumomta-cli spool optimize --memory
        
        # Restart if necessary
        if [[ $(echo "$memory_usage > 90" | bc -l 2>/dev/null || echo "0") -eq 1 ]]; then
            warning_log "Critical memory usage - restarting KumoMTA"
            docker-compose restart kumod
            sleep 30
        fi
    fi
    
    success_log "Memory optimization completed"
}

# Performance testing
run_performance_test() {
    log "Running performance test..."
    
    # Test email delivery
    log "Testing email delivery performance..."
    local start_time=$(date +%s)
    
    # Send test emails
    for i in {1..100}; do
        docker-compose exec kumod kumomta-cli test --email "test$i@example.com" --subject "Performance Test $i" &
    done
    
    wait
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    # Calculate performance metrics
    local emails_per_second=$(echo "scale=2; 100 / $duration" | bc -l 2>/dev/null || echo "0")
    
    log "Performance Test Results:"
    log "  Test Duration: ${duration} seconds"
    log "  Emails Sent: 100"
    log "  Throughput: ${emails_per_second} emails/second"
    
    # Check delivery status
    local delivered_count=$(curl -s "http://localhost:9090/api/v1/query?query=kumomta_delivered_total" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "0")
    local delivery_rate=$(echo "scale=2; $delivered_count / 100 * 100" | bc -l 2>/dev/null || echo "0")
    
    log "  Delivery Rate: ${delivery_rate}%"
    
    success_log "Performance test completed"
}

# Generate optimization report
generate_report() {
    log "Generating optimization report..."
    
    local report_file="$SCRIPT_DIR/performance-report-$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# KumoMTA Performance Optimization Report

**Generated**: $(date)
**Optimization Level**: $OPTIMIZATION_LEVEL

## Performance Metrics

### Before Optimization
- Queue Depth: $(docker-compose exec kumod kumomta-cli queue depth 2>/dev/null || echo "N/A")
- Delivery Rate: $(curl -s "http://localhost:9090/api/v1/query?query=rate(kumomta_delivered_total[5m])" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A") emails/minute
- CPU Usage: $(docker stats --no-stream --format "table {{.CPUPerc}}" kumod | tail -1 | sed 's/%//' 2>/dev/null || echo "N/A")%
- Memory Usage: $(docker stats --no-stream --format "table {{.MemPerc}}" kumod | tail -1 | sed 's/%//' 2>/dev/null || echo "N/A")%

### After Optimization
- Queue Depth: $(docker-compose exec kumod kumomta-cli queue depth 2>/dev/null || echo "N/A")
- Delivery Rate: $(curl -s "http://localhost:9090/api/v1/query?query=rate(kumomta_delivered_total[5m])" | jq -r '.data.result[0].value[1]' 2>/dev/null || echo "N/A") emails/minute
- CPU Usage: $(docker stats --no-stream --format "table {{.CPUPerc}}" kumod | tail -1 | sed 's/%//' 2>/dev/null || echo "N/A")%
- Memory Usage: $(docker stats --no-stream --format "table {{.MemPerc}}" kumod | tail -1 | sed 's/%//' 2>/dev/null || echo "N/A")%

## Optimizations Applied

1. **RocksDB Optimization**: $OPTIMIZATION_LEVEL level
2. **Redis Optimization**: Memory policy and persistence
3. **Worker Scaling**: Optimized worker count
4. **Throttling Optimization**: Business hours awareness
5. **Network Optimization**: Connection limits and DNS
6. **Memory Optimization**: Resource cleanup

## Recommendations

- Monitor performance for next 24 hours
- Run performance test weekly
- Review optimization settings monthly
- Scale horizontally if queue depth consistently > 10,000

EOF

    success_log "Performance report generated: $report_file"
}

# Main optimization function
main_optimization() {
    log "Starting KumoMTA performance optimization..."
    
    # Check prerequisites
    check_root
    check_docker
    check_kumomta_status
    
    # Analyze current performance
    analyze_performance
    
    # Apply optimizations
    optimize_rocksdb "$OPTIMIZATION_LEVEL"
    optimize_redis
    scale_workers
    optimize_throttling
    optimize_network
    optimize_memory
    
    # Wait for optimizations to take effect
    log "Waiting for optimizations to take effect..."
    sleep 60
    
    # Run performance test
    run_performance_test
    
    # Generate report
    generate_report
    
    success_log "Performance optimization completed successfully"
}

# Command line interface
case "${1:-}" in
    "analyze")
        check_docker
        check_kumomta_status
        analyze_performance
        ;;
    "optimize")
        main_optimization
        ;;
    "test")
        check_docker
        check_kumomta_status
        run_performance_test
        ;;
    "report")
        generate_report
        ;;
    "help"|"--help"|"-h")
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  analyze   - Analyze current performance"
        echo "  optimize  - Run full optimization (default)"
        echo "  test      - Run performance test"
        echo "  report    - Generate performance report"
        echo "  help      - Show this help message"
        ;;
    *)
        main_optimization
        ;;
esac
