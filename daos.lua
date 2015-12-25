local utils = require "kong.tools.utils"
local stringy = require "stringy"
local BaseDao = require "kong.dao.cassandra.base_dao"

local function generate_if_missing(v, t, column)
  if not v or stringy.strip(v) == "" then
    return true, nil, { [column] = utils.random_string()}
  end
  return true
end

local SCHEMA = {
  primary_key = {"id"},
  fields = {
    -- TODO require consumer_id
    id = { type = "id", dao_insert_value = true },
    consumer_id = { type = "id", required = false, queryable = true, foreign = "consumers:id" },
    idempotency_token = { type = "id", required = true, queryable = true },
    created_at = { type = "timestamp", dao_insert_value = true }
  }
}

local KongIdempotency = BaseDao:extend()

function KongIdempotency:new(properties)
  self._table = "kong_idempotency"
  self._schema = SCHEMA

  KongIdempotency.super.new(self, properties)
end

return { kong_idempotency = KongIdempotency }
