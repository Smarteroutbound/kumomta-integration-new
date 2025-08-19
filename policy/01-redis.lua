-- Redis configuration for KumoMTA
-- This file sets up Redis connection pools

local M = {}

function M.configure()
    -- Define Redis pool for tenant configuration
    kumo.redis_pool {
        name = 'redis-main',
        host = 'redis',
        port = 6379,
        pool_size = 10
    }
    
    kumo.log.info("Redis pool 'redis-main' configured successfully")
end

return M