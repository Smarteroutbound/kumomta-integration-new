# 🚀 **KUMOMTA OPERATIONAL RUNBOOK**

*Complete operational procedures for Smarter Outbound KumoMTA infrastructure*

---

## 📋 **DAILY OPERATIONS CHECKLIST**

### **🌅 Morning Health Check (9:00 AM)**

#### **1. System Health Verification**
```bash
# Check all container status
docker-compose ps

# Verify all services are healthy
docker-compose exec kumod curl -f http://localhost:8000/health
docker-compose exec tsa-daemon curl -f http://localhost:8008/health
docker-compose exec redis redis-cli ping
```

#### **2. Performance Metrics Review**
```bash
# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {instance: .labels.instance, health: .health}'

# Review overnight metrics
curl -s "http://localhost:9090/api/v1/query?query=rate(kumomta_delivered_total[8h])" | jq
```

#### **3. Queue Status Check**
```bash
# Check email queue depth
docker-compose exec kumod kumomta-cli queue depth

# Verify no stuck messages
docker-compose exec kumod kumomta-cli queue list --stuck
```

### **🌆 Afternoon Performance Review (2:00 PM)**

#### **1. Business Metrics Analysis**
- Review delivery rates for all client domains
- Check IP reputation scores
- Monitor bounce and complaint rates
- Review campaign performance metrics

#### **2. Capacity Planning**
```bash
# Check resource usage
docker stats --no-stream

# Monitor disk space
df -h /var/spool/kumomta/
```

### **🌙 Evening Maintenance (8:00 PM)**

#### **1. Log Review**
```bash
# Check for errors in last 12 hours
docker-compose logs --since="12h" kumod | grep -i error

# Review TSA daemon logs
docker-compose logs --since="12h" tsa-daemon | grep -i warning
```

#### **2. Performance Optimization**
```bash
# Check RocksDB compaction status
docker-compose exec kumod kumomta-cli spool status

# Verify Redis memory usage
docker-compose exec redis redis-cli info memory
```

---

## 🚨 **INCIDENT RESPONSE PROCEDURES**

### **🔴 CRITICAL INCIDENTS (Response: IMMEDIATE)**

#### **Email Delivery Completely Stopped**
```bash
# 1. Emergency Assessment
docker-compose exec kumod kumomta-cli queue depth
docker-compose exec kumod kumomta-cli spool status

# 2. Service Restart (if needed)
docker-compose restart kumod

# 3. Verify Recovery
docker-compose exec kumod curl -f http://localhost:8000/health
```

#### **IP Reputation Crisis (< 50)**
```bash
# 1. Immediate IP Rotation
docker-compose exec kumod kumomta-cli ip rotate --emergency

# 2. Check Blacklist Status
curl -s "http://localhost:8000/api/ip/status" | jq

# 3. Notify Affected Clients
# Use Django admin to send notifications
```

#### **High Bounce Rate (> 20%)**
```bash
# 1. Pause Problematic Campaigns
docker-compose exec kumod kumomta-cli campaign pause --bounce-rate-threshold 0.2

# 2. Analyze Bounce Patterns
docker-compose exec kumod kumomta-cli analytics bounces --last-24h

# 3. Implement Rate Limiting
docker-compose exec kumod kumomta-cli throttle set --domain-problematic.com --rate 100
```

### **🟡 WARNING INCIDENTS (Response: Within 1 Hour)**

#### **Performance Degradation**
```bash
# 1. Performance Analysis
docker-compose exec kumod kumomta-cli performance analyze

# 2. Resource Optimization
docker-compose exec kumod kumomta-cli spool optimize

# 3. Monitor Recovery
watch -n 30 'docker-compose exec kumod kumomta-cli performance metrics'
```

#### **High Queue Depth (> 5,000)**
```bash
# 1. Queue Analysis
docker-compose exec kumod kumomta-cli queue analyze

# 2. Increase Processing Capacity
docker-compose exec kumod kumomta-cli worker scale --count +2

# 3. Monitor Queue Reduction
watch -n 10 'docker-compose exec kumod kumomta-cli queue depth'
```

### **🟢 MINOR INCIDENTS (Response: Within 4 Hours)**

#### **Monitoring Alerts**
```bash
# 1. Alert Investigation
curl -s "http://localhost:9093/api/v1/alerts" | jq

# 2. False Positive Check
docker-compose exec kumod kumomta-cli alert verify --alert-id ALERT_ID

# 3. Alert Tuning (if needed)
# Edit monitoring/prometheus.rules.yml
```

---

## ⚡ **PERFORMANCE TUNING GUIDE**

### **🚀 High-Volume Optimization**

#### **For 100K+ Emails/Day**
```bash
# 1. Increase Worker Processes
docker-compose exec kumod kumomta-cli worker scale --count 8

# 2. Optimize RocksDB
docker-compose exec kumod kumomta-cli spool optimize --aggressive

# 3. Redis Memory Optimization
docker-compose exec redis redis-cli config set maxmemory-policy allkeys-lru
docker-compose exec redis redis-cli config set maxmemory 4gb
```

#### **For 1M+ Emails/Day**
```bash
# 1. Horizontal Scaling
docker-compose -f docker-compose.scale.yml up -d --scale kumod=3

# 2. Load Balancer Configuration
# Configure nginx or haproxy for SMTP traffic distribution

# 3. Database Optimization
docker-compose exec kumod kumomta-cli spool partition --shards 4
```

### **📊 Business Hours Optimization**

#### **Peak Hours (9 AM - 5 PM)**
```bash
# 1. Increase Delivery Rates
docker-compose exec kumod kumomta-cli throttle set --global --rate 2000

# 2. Optimize IP Rotation
docker-compose exec kumod kumomta-cli ip optimize --business-hours

# 3. Monitor Performance
watch -n 60 'docker-compose exec kumod kumomta-cli performance metrics'
```

#### **Off-Peak Hours (6 PM - 8 AM)**
```bash
# 1. Reduce Delivery Rates
docker-compose exec kumod kumomta-cli throttle set --global --rate 500

# 2. Maintenance Mode
docker-compose exec kumod kumomta-cli maintenance enable --reason "off-peak-optimization"

# 3. Background Tasks
docker-compose exec kumod kumomta-cli spool cleanup
docker-compose exec kumod kumomta-cli analytics aggregate
```

---

## 🔧 **MAINTENANCE PROCEDURES**

### **📅 Weekly Maintenance**

#### **Sunday 2:00 AM - Low Traffic Window**
```bash
# 1. Database Maintenance
docker-compose exec kumod kumomta-cli spool compact
docker-compose exec kumod kumomta-cli spool optimize

# 2. Log Rotation
docker-compose exec kumod kumomta-cli log rotate

# 3. Performance Analysis
docker-compose exec kumod kumomta-cli performance analyze --full
```

### **📅 Monthly Maintenance**

#### **First Sunday of Month**
```bash
# 1. Security Updates
docker-compose pull
docker-compose up -d --force-recreate

# 2. Configuration Review
# Review all policy files and configurations

# 3. Capacity Planning
# Analyze growth trends and plan scaling
```

---

## 📊 **MONITORING & ALERTING**

### **🔍 Key Metrics to Watch**

#### **Business Metrics**
- **Delivery Rate**: Target > 95%
- **Bounce Rate**: Target < 5%
- **Complaint Rate**: Target < 0.1%
- **Queue Depth**: Target < 1,000
- **IP Reputation**: Target > 80

#### **Technical Metrics**
- **Response Time**: Target < 10 seconds
- **Error Rate**: Target < 0.1%
- **Resource Usage**: CPU < 80%, Memory < 85%
- **Disk Space**: Available > 20%

### **📱 Alert Channels**
- **Critical**: SMS + Email + Slack
- **Warning**: Email + Slack
- **Info**: Slack only

---

## 🚀 **SCALING PROCEDURES**

### **📈 Horizontal Scaling**

#### **Add KumoMTA Instances**
```bash
# 1. Scale Services
docker-compose -f docker-compose.scale.yml up -d --scale kumod=3

# 2. Configure Load Balancer
# Update nginx/haproxy configuration

# 3. Verify Distribution
docker-compose exec kumod kumomta-cli cluster status
```

#### **Database Scaling**
```bash
# 1. Add Read Replicas
docker-compose -f docker-compose.db.yml up -d

# 2. Configure Connection Pooling
# Update policy files for multi-database support

# 3. Performance Testing
# Run load tests to verify scaling
```

---

## 🆘 **EMERGENCY CONTACTS**

### **👥 On-Call Team**
- **Primary**: [Your Name] - [Phone] - [Email]
- **Secondary**: [Backup Name] - [Phone] - [Email]
- **Escalation**: [Manager Name] - [Phone] - [Email]

### **🔧 External Support**
- **KumoMTA Support**: [Contact Info]
- **Infrastructure Provider**: [Contact Info]
- **DNS Provider**: [Contact Info]

---

## 📚 **USEFUL COMMANDS REFERENCE**

### **🔍 Health Checks**
```bash
# Service health
docker-compose exec kumod curl -f http://localhost:8000/health

# Queue status
docker-compose exec kumod kumomta-cli queue status

# Performance metrics
docker-compose exec kumod kumomta-cli performance metrics
```

### **📊 Analytics**
```bash
# Delivery statistics
docker-compose exec kumod kumomta-cli analytics delivery --last-24h

# IP reputation
docker-compose exec kumod kumomta-cli ip reputation

# Campaign performance
docker-compose exec kumod kumomta-cli campaign stats
```

### **⚙️ Configuration**
```bash
# Reload policies
docker-compose exec kumod kumomta-cli policy reload

# Update throttles
docker-compose exec kumod kumomta-cli throttle set --domain example.com --rate 1000

# IP management
docker-compose exec kumod kumomta-cli ip add --ip 192.168.1.100 --pool primary
```

---

*This runbook should be updated regularly based on operational experience and system changes.*
