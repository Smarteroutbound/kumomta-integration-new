#!/bin/bash

# KumoMTA Production Deployment Script
# Switches to production configuration with monitoring

set -e

echo "=== KumoMTA Production Deployment ==="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# Stop current services
echo "Stopping current services..."
docker-compose down || true

# Backup current config
echo "Backing up current configuration..."
cp docker-compose.yml docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S) || true

# Switch to production config
echo "Switching to production configuration..."
cp docker-compose.production.yml docker-compose.yml

# Create necessary directories
echo "Creating directories..."
mkdir -p keys logs

# Set permissions
echo "Setting permissions..."
chmod 755 keys logs
chmod 644 keys/README.md

# Pull latest images
echo "Pulling latest images..."
docker-compose pull

# Start services
echo "Starting production services..."
docker-compose up -d

# Wait for services to start
echo "Waiting for services to start..."
sleep 30

# Check service health
echo "Checking service health..."
docker-compose ps

# Test endpoints
echo "Testing endpoints..."
curl -f http://localhost:8000/health || echo "KumoMTA health check failed"
curl -f http://localhost:9090/-/healthy || echo "Prometheus health check failed"
curl -f http://localhost:3000/api/health || echo "Grafana health check failed"

echo ""
echo "=== Deployment Complete ==="
echo "Services:"
echo "  KumoMTA:    http://localhost:8000"
echo "  Prometheus: http://localhost:9090"
echo "  Grafana:    http://localhost:3000 (admin/kumomta123)"
echo "  Redis:      localhost:6379"
echo ""
echo "To view logs: docker-compose logs -f"
echo "To stop:      docker-compose down"