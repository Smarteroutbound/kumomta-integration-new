local M = {}

function M.configure()
    kumo.redis.configure {
        node = 'redis://localhost:6379/',
        pool_size = 50,
        cluster_mode = false
    }
    kumo.log_info("Redis module configured.")
end

return M