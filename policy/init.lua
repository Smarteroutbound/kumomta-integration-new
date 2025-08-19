--[[
KumoMTA Cold Email MTA Configuration
Production-ready policy for Smarter Outbound
]]

-- Initialize KumoMTA properly
kumo.on('init', function()
    -- Define the default "data" spool location
    kumo.define_spool {
        name = 'data',
        path = '/var/spool/kumomta/data',
        kind = 'RocksDB',
    }

    -- Define the default "meta" spool location
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

    -- Configure Redis throttles
    kumo.configure_redis_throttles {
        node = 'redis://redis:6379/'
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

print("KumoMTA policy loaded successfully")