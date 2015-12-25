local responses = require "kong.tools.responses"
local inspect = require "inspect"
local _M = {}

local function read_response_body()
    local chunk, eof = ngx.arg[1], ngx.arg[2]
    local buffered = ngx.ctx.buffered
    if not buffered then
        buffered = {}
        ngx.ctx.buffered = buffered
    end
    if chunk ~= "" then
        buffered[#buffered + 1] = chunk
    end
    if eof then
        local response_body = table.concat(buffered)
        return response_body
    end
    return nil
end

local function save_response_to_db(idempotency_token, response_body)
    local inserted, error = dao.kong_idempotency:insert({ idempotency_token = idempotency_token, response = response_body })
    if error then
        ngx.log(ngx.ERR, "Error occured while saving response to database: " .. inspect(error))
        return responses.send_HTTP_INTERNAL_SERVER_ERROR(err)
    elseif inserted then
        ngx.log(ngx.ERR, "Successfully inserted object: " .. inspect(inserted))
    end
end

function _M.execute(conf)
    local response_body = read_response_body()
    local idempotency_token = ngx.req.get_headers()["Idempotency-Token"]
    if response_body and string.len(response_body) > 0 and idempotency_token then
        -- save_response_to_db(idempotency_token, response_body)
    end
end

return _M
