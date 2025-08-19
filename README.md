# KumoMTA Cold Email Integration

Simple KumoMTA setup for cold email delivery with Redis integration.

## Quick Start

1. **Clone and start:**
   ```bash
   git clone https://github.com/Smarteroutbound/kumomta-integration-new.git
   cd kumomta-integration-new
   sudo docker-compose up -d
   ```

2. **Check logs:**
   ```bash
   sudo docker-compose logs kumod-cold-email
   ```

## What This Provides

- **SMTP Relay**: Accepts emails on ports 25 and 587
- **Redis Integration**: For rate limiting and throttles
- **RocksDB Storage**: Efficient message storage
- **Logging**: Comprehensive delivery logging

## Configuration

- `policy/init.lua`: Main KumoMTA configuration
- `docker-compose.yml`: Container setup with Redis
- Ports: 25 (SMTP), 587 (Submission), 2025 (Monitoring)

## Integration

- **Django**: Can send emails via SMTP to this relay
- **Mailcow**: Can use as external SMTP relay
- **Redis**: Shared rate limiting across instances
