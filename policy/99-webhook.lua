-- Webhook handler for delivery logs
local M = {}

function M.send_delivery_log(log)
    -- Webhook logic will be added here
    kumo.log_info('Delivery log generated: ' .. tostring(log))
end

return M