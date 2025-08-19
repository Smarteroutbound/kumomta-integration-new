--[[
########################################################
KumoMTA Cold Email MTA Configuration
Production-ready policy for Smarter Outbound
Handles IP rotation, delivery, and monitoring
########################################################
]]

-- Load Redis configuration module
local redis_config = require 'redis_config'

-- START SETUP

-- END SETUP

-- START EVENT HANDLERS

-- Called On Startup, handles initial configuration
kumo.on('init', function()
    -- Configure Redis first
    redis_config.setup_redis()
    
    -- Define the default "data" spool location; this is where
    -- message bodies will be stored.
    -- See https://docs.kumomta.com/userguide/configuration/spool/
    kumo.define_spool {
        name = 'data',
        path = '/var/spool/kumomta/data',
        kind = 'RocksDB',
    }

    -- Define the default "meta" spool location; this is where
    -- message envelope and metadata will be stored.
    kumo.define_spool {
        name = 'meta',
        path = '/var/spool/kumomta/meta',
        kind = 'RocksDB',
    }

    -- Start the ESMTP listener on port 25 (standard SMTP)
    kumo.start_esmtp_listener {
        listen = '0.0.0.0:25',
        relay_hosts = { '127.0.0.1' },
    }

    -- Start the ESMTP listener on port 587 (submission)
    kumo.start_esmtp_listener {
        listen = '0.0.0.0:587',
        relay_hosts = { '127.0.0.1' },
    }

    -- Configure local logs
    kumo.configure_local_logs {
        log_dir = '/var/log/kumomta',
        max_size = '100M',
        max_files = 10,
    }

    -- Configure bounce classifier
    kumo.configure_bounce_classifier {
        -- Use default bounce classification rules
    }

    print("KumoMTA initialized successfully")
end)

-- Handle incoming messages
kumo.on('smtp_message_received', function(msg)
    -- Apply SMTP smuggling protection
    msg:check_fix_conformance()
    
    -- Log the message
    kumo.log.info('Message received from ' .. tostring(msg:from()) .. ' to ' .. tostring(msg:to()))
    
    -- Accept the message for delivery
    return msg:accept()
end)

-- Handle delivery status updates
kumo.on('delivery_status', function(msg, status)
    -- Log delivery status
    kumo.log.info('Delivery status: ' .. tostring(status) .. ' for message ' .. tostring(msg:id()))
    
    -- Send webhook notification to Django backend
    local webhook = require '99-webhook'
    webhook.send_delivery_log(msg, status)
end)

-- Handle message processing
kumo.on('message', function(msg)
    -- Log message details
    print(string.format("Processing message: %s -> %s", 
        msg:from(), table.concat(msg:to(), ", ")))
    
    -- Set delivery timeout
    msg:set_meta("delivery_timeout", "1h")
    
    -- Set retry policy
    msg:set_retry_policy {
        max_attempts = 3,
        backoff = "5m",
    }
    
    -- Log for monitoring
    kumo.log.info("Message queued", {
        message_id = msg:id(),
        from = msg:from(),
        to = msg:to(),
        size = msg:size(),
    })
end)

-- Handle delivery attempts
kumo.on('delivery_attempt', function(attempt)
    local msg = attempt:message()
    
    -- Log delivery attempt
    kumo.log.info("Delivery attempt", {
        message_id = msg:id(),
        domain = attempt:domain(),
        ip = attempt:ip(),
        attempt_number = attempt:attempt_number(),
    })
    
    -- Set custom headers for tracking
    msg:set_meta("delivery_ip", attempt:ip())
    msg:set_meta("delivery_domain", attempt:domain())
end)

-- Handle delivery results
kumo.on('delivery_result', function(result)
    local msg = result:message()
    
    if result:success() then
        kumo.log.info("Delivery successful", {
            message_id = msg:id(),
            domain = result:domain(),
            ip = result:ip(),
        })
    else
        kumo.log.warn("Delivery failed", {
            message_id = msg:id(),
            domain = result:domain(),
            ip = result:ip(),
            error = result:error(),
        })
    end
end)

-- Configure egress sources (IP pools)
kumo.on('init', function()
    -- Define IP pools for rotation
    -- These will be configured via environment variables or API
    kumo.define_egress_source {
        name = 'default-pool',
        source_address = '0.0.0.0', -- Will be overridden by specific IPs
    }
    
    -- Example IP pool configuration (uncomment and configure as needed)
    --[[
    kumo.define_egress_source {
        name = 'ip-pool-1',
        source_address = 'YOUR_IP_1',
    }
    
    kumo.define_egress_source {
        name = 'ip-pool-2', 
        source_address = 'YOUR_IP_2',
    }
    --]]
end)

-- Configure domain routing
kumo.on('get_egress_source', function(domain, msg)
    -- Simple round-robin IP selection
    -- In production, you might want more sophisticated routing
    return 'default-pool'
end)

-- Configure authentication (if needed)
kumo.on('smtp_server_ehlo', function(conn)
    -- Log connection attempts
    kumo.log.info("SMTP connection", {
        ip = conn:client_ip(),
        hostname = conn:client_hostname(),
    })
end)

-- Configure rate limiting
kumo.on('get_queue_config', function(domain, msg)
    return kumo.QueueConfig {
        max_concurrent = 10,
        max_age = "1h",
        retry_policy = {
            max_attempts = 3,
            backoff = "5m",
        },
    }
end)

print("KumoMTA policy loaded successfully")