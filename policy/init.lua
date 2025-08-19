--[[
KumoMTA Cold Email MTA Configuration
Production-ready policy for Smarter Outbound
]]

-- This is the minimal working configuration
-- All kumo calls must be inside event handlers

-- Initialize KumoMTA
kumo.on('init', function()
    -- Define spools
    kumo.define_spool {
        name = 'data',
        path = '/var/spool/kumomta/data',
        kind = 'RocksDB',
    }

    kumo.define_spool {
        name = 'meta',
        path = '/var/spool/kumomta/meta',
        kind = 'RocksDB',
    }

    -- Start SMTP listeners
    kumo.start_esmtp_listener {
        listen = '0.0.0.0:25',
        relay_hosts = { '127.0.0.1' },
    }

    kumo.start_esmtp_listener {
        listen = '0.0.0.0:587',
        relay_hosts = { '127.0.0.1' },
    }

    -- Configure logging
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
    msg:check_fix_conformance()
    kumo.log.info('Message received from ' .. tostring(msg:from()) .. ' to ' .. tostring(msg:to()))
    return msg:accept()
end)

print("KumoMTA policy loaded successfully")