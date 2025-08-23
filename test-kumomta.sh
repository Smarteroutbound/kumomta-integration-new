#!/bin/bash

echo "🧪 Testing KumoMTA Integration After Fixes"
echo "=========================================="

# Test 1: Check if containers are running
echo "📦 Checking container status..."
docker ps --filter "name=kumo" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "🔍 Testing KumoMTA Health Endpoints..."

# Test 2: Test KumoMTA health endpoint
echo "🏥 Testing /health endpoint..."
curl -s http://localhost:8000/health | jq '.' 2>/dev/null || curl -s http://localhost:8000/health

echo ""
echo "📊 Testing /api/v1/status endpoint..."
curl -s http://localhost:8000/api/v1/status | jq '.' 2>/dev/null || curl -s http://localhost:8000/api/v1/status

echo ""
echo "📈 Testing /api/v1/metrics/delivery endpoint..."
curl -s http://localhost:8000/api/v1/metrics/delivery | jq '.' 2>/dev/null || curl -s http://localhost:8000/api/v1/metrics/delivery

echo ""
echo "🔌 Testing SMTP ports..."
echo "Port 25 (External SMTP):"
nc -zv localhost 25 2>&1 || echo "Port 25 not accessible"

echo "Port 2525 (Internal Relay):"
nc -zv localhost 2525 2>&1 || echo "Port 2525 not accessible"

echo "Port 587 (Submission):"
nc -zv localhost 587 2>&1 || echo "Port 587 not accessible"

echo ""
echo "📊 Testing monitoring endpoints..."
echo "Prometheus:"
curl -s http://localhost:9090/-/healthy 2>/dev/null && echo "✅ Prometheus healthy" || echo "❌ Prometheus not accessible"

echo "Grafana:"
curl -s http://localhost:3000/api/health 2>/dev/null && echo "✅ Grafana healthy" || echo "❌ Grafana not accessible"

echo "Redis:"
curl -s http://localhost:6379 2>/dev/null && echo "✅ Redis accessible" || echo "❌ Redis not accessible"

echo ""
echo "🧪 Test completed!"
