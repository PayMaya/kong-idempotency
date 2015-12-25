local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.kong-idempotency.access"
local body_filter = require "kong.plugins.kong-idempotency.body_filter"

local KongIdempotencyHandler = BasePlugin:extend()

function KongIdempotencyHandler:new()
    KongIdempotencyHandler.super.new(self, "kong-idempotency")
end

function KongIdempotencyHandler:access(conf)
    KongIdempotencyHandler.super.access(self)
    access.execute(conf)
end

function KongIdempotencyHandler:body_filter(conf)
    KongIdempotencyHandler.super.body_filter(self)
    body_filter.execute(conf)
end

return KongIdempotencyHandler
