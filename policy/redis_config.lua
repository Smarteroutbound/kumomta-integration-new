-- policy/redis_config.lua

local M = {}

-- This function defines the redis pool. It will be called from init.lua
function M.setup_redis()
  -- Check if the pool is already defined to avoid errors on reload
  if not kumo.redis_pool_by_name 'redis-main' then
    kumo.log.info('Defining Redis pool redis-main')
    kumo.redis_pool {
      name = 'redis-main',
      host = 'redis', -- This uses the redis service from your docker-compose file
    }
  end
end

-- This function is a helper to get a redis connection from other files
function M.get_connection()
  return kumo.redis_pool_by_name('redis-main'):get_connection()
end

-- Return the module table
return M