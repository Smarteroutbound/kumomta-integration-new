# 🚨 **KUMOMTA DISASTER RECOVERY PLAN**

_Comprehensive disaster recovery procedures for Smarter Outbound email infrastructure_

---

## 🎯 **RECOVERY OBJECTIVES**

### **RTO (Recovery Time Objective)**

- **Critical Services**: 15 minutes
- **Full System**: 2 hours
- **Data Recovery**: 4 hours

### **RPO (Recovery Point Objective)**

- **Email Queue**: 5 minutes
- **Configuration**: 1 hour
- **Analytics Data**: 24 hours

---

## 🔄 **BACKUP STRATEGY**

### **📦 Automated Backups**

#### **1. Configuration Backups**

```bash
#!/bin/bash
# backup-config.sh - Daily configuration backup
BACKUP_DIR="/opt/backups/kumomta/config"
DATE=$(date +%Y%m%d_%H%M%S)

# Backup policy files
tar -czf $BACKUP_DIR/policy_$DATE.tar.gz ./policy/

# Backup Docker Compose files
cp docker-compose.yml $BACKUP_DIR/docker-compose_$DATE.yml

# Backup monitoring configuration
tar -czf $BACKUP_DIR/monitoring_$DATE.tar.gz ./monitoring/

# Backup environment variables
env | grep KUMO > $BACKUP_DIR/env_$DATE.txt

# Cleanup old backups (keep 30 days)
find $BACKUP_DIR -name "*.tar.gz" -mtime +30 -delete
find $BACKUP_DIR -name "*.yml" -mtime +30 -delete
find $BACKUP_DIR -name "*.txt" -mtime +30 -delete
```

#### **2. Data Backups**

```bash
#!/bin/bash
# backup-data.sh - Daily data backup
BACKUP_DIR="/opt/backups/kumomta/data"
DATE=$(date +%Y%m%d_%H%M%S)

# Backup RocksDB spools
docker-compose exec kumod tar -czf /tmp/spool_$DATE.tar.gz /var/spool/kumomta/
docker cp kumod:/tmp/spool_$DATE.tar.gz $BACKUP_DIR/

# Backup Redis data
docker-compose exec redis redis-cli BGSAVE
docker cp kumod:/data/dump.rdb $BACKUP_DIR/redis_$DATE.rdb

# Backup Prometheus data
docker cp kumo-prometheus:/prometheus $BACKUP_DIR/prometheus_$DATE/

# Cleanup old backups (keep 7 days)
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
find $BACKUP_DIR -name "*.rdb" -mtime +7 -delete
find $BACKUP_DIR -name "prometheus_*" -mtime +7 -exec rm -rf {} \;
```

#### **3. Backup Verification**

```bash
#!/bin/bash
# verify-backup.sh - Verify backup integrity
BACKUP_DIR="/opt/backups/kumomta"

echo "🔍 Verifying latest backups..."

# Check configuration backup
LATEST_CONFIG=$(ls -t $BACKUP_DIR/config/policy_*.tar.gz | head -1)
if [ -f "$LATEST_CONFIG" ]; then
    echo "✅ Configuration backup: $LATEST_CONFIG"
    tar -tzf "$LATEST_CONFIG" > /dev/null && echo "   Integrity: OK" || echo "   Integrity: FAILED"
else
    echo "❌ No configuration backup found"
fi

# Check data backup
LATEST_DATA=$(ls -t $BACKUP_DIR/data/spool_*.tar.gz | head -1)
if [ -f "$LATEST_DATA" ]; then
    echo "✅ Data backup: $LATEST_DATA"
    tar -tzf "$LATEST_DATA" > /dev/null && echo "   Integrity: OK" || echo "   Integrity: FAILED"
else
    echo "❌ No data backup found"
fi

# Check Redis backup
LATEST_REDIS=$(ls -t $BACKUP_DIR/data/redis_*.rdb | head -1)
if [ -f "$LATEST_REDIS" ]; then
    echo "✅ Redis backup: $LATEST_REDIS"
    echo "   Size: $(du -h "$LATEST_REDIS" | cut -f1)"
else
    echo "❌ No Redis backup found"
fi
```

---

## 🚨 **DISASTER SCENARIOS & RECOVERY**

### **🔴 SCENARIO 1: Complete System Failure**

#### **Symptoms**

- All containers down
- No response from any service
- Complete email delivery failure

#### **Recovery Procedure**

```bash
# 1. Emergency Assessment
echo "🚨 EMERGENCY: Complete system failure detected"
echo "Time: $(date)"
echo "Starting emergency recovery procedure..."

# 2. Stop All Services
docker-compose down --remove-orphans

# 3. Verify Infrastructure
echo "🔍 Checking infrastructure status..."
docker --version
docker-compose --version
df -h
free -h

# 4. Restore from Latest Backup
LATEST_BACKUP=$(ls -t /opt/backups/kumomta/config/docker-compose_*.yml | head -1)
if [ -f "$LATEST_BACKUP" ]; then
    echo "📦 Restoring from backup: $LATEST_BACKUP"
    cp "$LATEST_BACKUP" docker-compose.yml
else
    echo "❌ No backup found - using default configuration"
fi

# 5. Restart Services
echo "🚀 Restarting services..."
docker-compose up -d

# 6. Verify Recovery
echo "🔍 Verifying recovery..."
sleep 30
docker-compose ps
docker-compose exec kumod curl -f http://localhost:8000/health

# 7. Test Email Delivery
echo "📧 Testing email delivery..."
docker-compose exec kumod kumomta-cli test --email test@example.com

echo "✅ Recovery procedure completed at $(date)"
```

### **🟡 SCENARIO 2: Data Corruption**

#### **Symptoms**

- Service running but data inconsistent
- Email delivery errors
- Monitoring data gaps

#### **Recovery Procedure**

```bash
# 1. Identify Corrupted Data
echo "🔍 Identifying corrupted data..."
docker-compose exec kumod kumomta-cli spool status
docker-compose exec kumod kumomta-cli queue status

# 2. Stop Affected Services
echo "⏹️ Stopping affected services..."
docker-compose stop kumod

# 3. Restore Data from Backup
echo "📦 Restoring data from backup..."
LATEST_DATA_BACKUP=$(ls -t /opt/backups/kumomta/data/spool_*.tar.gz | head -1)
if [ -f "$LATEST_DATA_BACKUP" ]; then
    echo "Restoring from: $LATEST_DATA_BACKUP"
    docker-compose exec kumod rm -rf /var/spool/kumomta/data/*
    docker cp "$LATEST_DATA_BACKUP" kumod:/tmp/
    docker-compose exec kumod tar -xzf /tmp/spool_*.tar.gz -C /var/spool/kumomta/
else
    echo "❌ No data backup found - clearing corrupted data"
    docker-compose exec kumod rm -rf /var/spool/kumomta/data/*
fi

# 4. Restart Services
echo "🚀 Restarting services..."
docker-compose start kumod

# 5. Verify Data Integrity
echo "🔍 Verifying data integrity..."
sleep 30
docker-compose exec kumod kumomta-cli spool status
docker-compose exec kumod kumomta-cli queue status
```

### **🟢 SCENARIO 3: Performance Degradation**

#### **Symptoms**

- Slow email delivery
- High queue depth
- Resource exhaustion

#### **Recovery Procedure**

```bash
# 1. Performance Analysis
echo "🔍 Analyzing performance issues..."
docker-compose exec kumod kumomta-cli performance analyze
docker stats --no-stream

# 2. Resource Optimization
echo "⚡ Optimizing resources..."
docker-compose exec kumod kumomta-cli spool optimize
docker-compose exec redis redis-cli config set maxmemory-policy allkeys-lru

# 3. Scale Up (if needed)
echo "📈 Scaling up if needed..."
if [ $(docker-compose exec kumod kumomta-cli queue depth) -gt 10000 ]; then
    echo "High queue depth detected - scaling workers..."
    docker-compose exec kumod kumomta-cli worker scale --count +2
fi

# 4. Monitor Recovery
echo "📊 Monitoring recovery..."
watch -n 30 'docker-compose exec kumod kumomta-cli performance metrics'
```

---

## 🔄 **FAILOVER PROCEDURES**

### **🌐 Geographic Failover**

#### **Primary Site Failure**

```bash
# 1. Activate Secondary Site
echo "🌍 Activating secondary site..."
cd /opt/kumomta-secondary

# 2. Update DNS
echo "🔧 Updating DNS records..."
./update-dns.sh --failover

# 3. Start Services
echo "🚀 Starting secondary services..."
docker-compose up -d

# 4. Verify Failover
echo "🔍 Verifying failover..."
./health-check.sh
./email-test.sh

echo "✅ Failover to secondary site completed"
```

#### **Return to Primary Site**

```bash
# 1. Verify Primary Site Health
echo "🔍 Verifying primary site health..."
cd /opt/kumomta-primary
./health-check.sh

# 2. Sync Data
echo "🔄 Syncing data from secondary site..."
./sync-from-secondary.sh

# 3. Update DNS
echo "🔧 Updating DNS records..."
./update-dns.sh --failback

# 4. Verify Return
echo "🔍 Verifying return to primary site..."
./health-check.sh
./email-test.sh

echo "✅ Return to primary site completed"
```

### **⚖️ Load Balancer Failover**

#### **Active-Passive Configuration**

```bash
# 1. Check Primary Load Balancer
echo "🔍 Checking primary load balancer..."
curl -f http://primary-lb:8080/health

# 2. Activate Secondary Load Balancer
if [ $? -ne 0 ]; then
    echo "🚨 Primary load balancer failed - activating secondary..."
    ./activate-secondary-lb.sh
fi

# 3. Verify Traffic Distribution
echo "🔍 Verifying traffic distribution..."
./check-traffic-distribution.sh
```

---

## 📱 **NOTIFICATION & ESCALATION**

### **🚨 Alert Escalation Matrix**

#### **Level 1: Automated Alerts (0-15 minutes)**

- **Channel**: Slack + Email
- **Recipients**: On-call engineer
- **Actions**: Acknowledge alert, initial assessment

#### **Level 2: Escalation (15-30 minutes)**

- **Channel**: SMS + Phone call
- **Recipients**: Senior engineer + Team lead
- **Actions**: Join incident response, technical analysis

#### **Level 3: Management (30+ minutes)**

- **Channel**: Phone call + Executive notification
- **Recipients**: CTO + VP Engineering
- **Actions**: Business impact assessment, customer communication

### **📋 Notification Templates**

#### **Initial Alert**

```
🚨 INCIDENT ALERT: [SEVERITY] - [INCIDENT_TYPE]
Time: [TIMESTAMP]
Impact: [BUSINESS_IMPACT]
Status: Investigating
```

#### **Update Alert**

```
📊 INCIDENT UPDATE: [INCIDENT_ID]
Time: [TIMESTAMP]
Status: [CURRENT_STATUS]
ETA: [ESTIMATED_RESOLUTION]
Actions: [CURRENT_ACTIONS]
```

#### **Resolution Alert**

```
✅ INCIDENT RESOLVED: [INCIDENT_ID]
Time: [TIMESTAMP]
Duration: [TOTAL_DURATION]
Root Cause: [ROOT_CAUSE]
Prevention: [PREVENTIVE_MEASURES]
```

---

## 🧪 **RECOVERY TESTING**

### **📅 Testing Schedule**

#### **Weekly Tests**

- **Backup Verification**: Every Sunday 2:00 AM
- **Health Check Scripts**: Every Monday 9:00 AM
- **Failover Procedures**: Every other week

#### **Monthly Tests**

- **Full Disaster Recovery**: First Sunday of month
- **Performance Recovery**: Third Sunday of month
- **Data Recovery**: Last Sunday of month

### **🧪 Test Procedures**

#### **Backup Restoration Test**

```bash
#!/bin/bash
# test-backup-restore.sh - Test backup restoration
echo "🧪 Testing backup restoration..."

# 1. Create test environment
docker-compose -f docker-compose.test.yml up -d

# 2. Restore from backup
./restore-from-backup.sh --test

# 3. Verify functionality
./health-check.sh
./email-test.sh

# 4. Cleanup
docker-compose -f docker-compose.test.yml down

echo "✅ Backup restoration test completed"
```

#### **Failover Test**

```bash
#!/bin/bash
# test-failover.sh - Test failover procedures
echo "🧪 Testing failover procedures..."

# 1. Simulate primary site failure
docker-compose stop kumod

# 2. Activate failover
./activate-failover.sh

# 3. Verify failover functionality
./health-check.sh
./email-test.sh

# 4. Return to primary
docker-compose start kumod
./deactivate-failover.sh

echo "✅ Failover test completed"
```

---

## 📚 **RECOVERY DOCUMENTATION**

### **📖 Runbook References**

- **Daily Operations**: `OPERATIONAL_RUNBOOK.md`
- **Performance Tuning**: `PERFORMANCE_GUIDE.md`
- **Monitoring Setup**: `MONITORING_SETUP.md`

### **🔧 Tool Locations**

- **Backup Scripts**: `/opt/scripts/backup/`
- **Recovery Scripts**: `/opt/scripts/recovery/`
- **Test Scripts**: `/opt/scripts/testing/`
- **Documentation**: `/opt/docs/`

### **📞 Emergency Contacts**

- **Primary On-Call**: [Name] - [Phone] - [Email]
- **Secondary On-Call**: [Name] - [Phone] - [Email]
- **Management Escalation**: [Name] - [Phone] - [Email]
- **External Support**: [Vendor] - [Phone] - [Email]

---

## 🎯 **POST-RECOVERY ACTIONS**

### **📊 Incident Analysis**

1. **Root Cause Analysis**: Document what caused the incident
2. **Impact Assessment**: Quantify business impact
3. **Recovery Timeline**: Document recovery steps and timing
4. **Lessons Learned**: Identify improvements for future incidents

### **🔧 Preventive Measures**

1. **Configuration Updates**: Fix any configuration issues
2. **Monitoring Improvements**: Add alerts for similar issues
3. **Process Updates**: Improve recovery procedures
4. **Training**: Update team training based on incident

### **📈 Continuous Improvement**

1. **Recovery Time Analysis**: Track and improve RTO
2. **Recovery Point Analysis**: Track and improve RPO
3. **Procedure Updates**: Refine recovery procedures
4. **Testing Frequency**: Adjust testing schedule based on findings

---

_This disaster recovery plan should be reviewed and updated quarterly, and tested monthly to ensure effectiveness._
