local responses = require "kong.tools.responses"

local _M = {}

local function retrieve_record(idempotency_token)
    local record = nil
    local error = nil
    if idempotency_token then
        record, error = dao.kong_idempotency:find_by_keys { idempotency_token = idempotency_token }
    end
    if #record > 0 then
        record = record[1]
    else
        record = nil
    end
    return record, error
end

local function reject_request(idempotency_record)
    return responses.send_HTTP_BAD_REQUEST("Idempotency token already used: " .. idempotency_record.idempotency_token)
end

local function save_idempotency_token(token)
    local inserted, error = dao.kong_idempotency:insert({ idempotency_token = token })
end

function _M.execute(conf)
    local idempotency_token = ngx.req.get_headers()["Idempotency-Token"]
    local record, error = retrieve_record(idempotency_token)
    if error then
        return responses.send_HTTP_INTERNAL_SERVER_ERROR(error)
    elseif record then
        return reject_request(record)
    else
        save_idempotency_token(idempotency_token)
    end
end

return _M
