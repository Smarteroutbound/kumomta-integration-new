--[[
Webhook client for sending delivery status to Django
]]

local kumo = require 'kumo'

-- Django webhook configuration
local DJANGO_WEBHOOK_URL = os.getenv('DJANGO_WEBHOOK_URL') or 'http://localhost:8000/api/kumomta/webhook/'
local WEBHOOK_SECRET = os.getenv('KUMOMTA_WEBHOOK_SECRET') or 'your-secret-key'

-- Send delivery status to Django
local function send_delivery_status(msg, log_record)
  if not log_record then
    return
  end
  
  -- Extract message metadata
  local sender = msg:sender()
  local tenant_id = msg:get_meta('tenant_id')
  local ip_pool = msg:get_meta('ip_pool')
  local business_type = msg:get_meta('business_type')
  
  -- Build webhook payload
  local payload = {
    event_type = log_record.type or 'Unknown',
    timestamp_utc = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    tenant_id = tenant_id,
    message_id = msg:get_header('Message-ID') or 'unknown',
    sender = sender and tostring(sender) or 'unknown',
    recipient = log_record.recipient or 'unknown',
    sending_ip = ip_pool or 'unknown',
    delivery_protocol = 'Smtp',
    business_type = business_type,
    smtp_response = {}
  }
  
  -- Add SMTP response details if available
  if log_record.response then
    payload.smtp_response = {
      code = log_record.response.code or 0,
      enhanced_code = log_record.response.enhanced_code or '',
      content = log_record.response.content or '',
      command = log_record.response.command or 'UNKNOWN'
    }
  end
  
  -- Send webhook asynchronously
  local success, err = pcall(function()
    kumo.http.post {
      url = DJANGO_WEBHOOK_URL,
      headers = {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = 'Bearer ' .. WEBHOOK_SECRET,
        ['User-Agent'] = 'KumoMTA-Webhook/1.0'
      },
      body = kumo.json_encode(payload),
      timeout = '10s'
    }
  end)
  
  if success then
    kumo.log('debug', string.format('Webhook sent for %s: %s', 
      payload.sender, payload.event_type))
  else
    kumo.log('warn', string.format('Webhook failed for %s: %s', 
      payload.sender, tostring(err)))
  end
end

return {
  send_delivery_status = send_delivery_status
}