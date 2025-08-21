# 🚀 KumoMTA Fixed Deployment Guide

## 🔧 Issues Fixed

### ✅ Critical Issues Resolved:
1. **TSA Daemon Crash** - Removed TSA dependency from kumod service
2. **Port Conflicts** - Reverted to standard ports (25, 587, 8000)
3. **Prometheus Config Errors** - Disabled until config is fixed
4. **HAProxy Config Issues** - Disabled until config is fixed
5. **Grafana Dashboard Errors** - Disabled until dashboards are fixed

## 🚀 Quick Start (Minimal Deployment)

### Step 1: Use Minimal Configuration
```bash
# Stop any running containers
docker-compose down --remove-orphans

# Start with minimal services only
docker-compose -f docker-compose.minimal.yml up -d
```

### Step 2: Verify Core Services
```bash
# Check if services are running
docker-compose -f docker-compose.minimal.yml ps

# Check KumoMTA health
curl http://localhost:8000/health

# Check Redis
docker exec kumo-redis redis-cli ping
```

### Step 3: Test SMTP Functionality
```bash
# Test SMTP port
telnet localhost 25

# Test submission port
telnet localhost 587
```

## 📊 Service Status

### ✅ Working Services:
- **Redis** - Data storage and caching
- **KumoMTA Core** - SMTP server and API
- **Node Exporter** - Basic system metrics

### ❌ Disabled Services (until fixed):
- **TSA Daemon** - Causing crashes
- **Prometheus** - YAML config errors
- **Grafana** - Dashboard config errors
- **HAProxy** - Config file missing
- **Alertmanager** - Dependency on Prometheus
- **Nginx** - Not needed for core functionality
- **Fluentd** - Not needed for core functionality

## 🔧 Troubleshooting

### If KumoMTA fails to start:
```bash
# Check logs
docker logs kumod-enterprise

# Check policy file
docker exec kumod-enterprise cat /opt/kumomta/etc/policy/init.lua
```

### If Redis fails:
```bash
# Check Redis logs
docker logs kumo-redis

# Test Redis connection
docker exec kumo-redis redis-cli ping
```

## 🎯 Next Steps

### After Core Services Work:
1. **Test email delivery** via SMTP
2. **Verify API endpoints** work from Django
3. **Add monitoring services** one by one
4. **Fix Prometheus configuration**
5. **Fix Grafana dashboards**
6. **Re-enable TSA daemon** if needed

## 📧 Testing Email Delivery

### From Mailcow Server (149.28.244.166):
```bash
# Test SMTP relay to KumoMTA
echo "Subject: Test Email" | sendmail -f test@example.com -S 89.117.75.190:25 recipient@example.com
```

### From Django Server (151.236.251.75):
```bash
# Test KumoMTA API
curl http://89.117.75.190:8000/health
curl http://89.117.75.190:8000/api/v1/metrics
```

## 🚨 Important Notes

1. **Use minimal deployment first** - Get core working before adding complexity
2. **Standard ports restored** - 25 (SMTP), 587 (Submission), 8000 (API)
3. **TSA disabled** - Causing crashes, can be re-enabled later
4. **Monitoring simplified** - Only essential services enabled

**Your KumoMTA should now start successfully with core functionality!** 🎉