local spec_helper = require "spec.spec_helpers"
local http_client = require "kong.tools.http_client"
local cjson = require "cjson"
local constants = require "kong.constants"

local PROXY_URL = spec_helper.PROXY_URL


describe("Idempotency Plugin", function ()
    local DEFAULT_TOKEN = "de305d54-75b4-431b-adb2-eb6b9e546014"
    local CUSTOM_TOKEN_EXPIRY = 20000
    local DAY_IN_MILLIS = 86400000
    local MILLIS_IN_SECONDS = 1000
    local default_header
    local inserted_fixtures

    setup(function ()
        spec_helper.prepare_db()
        inserted_fixtures = spec_helper.insert_fixtures {
            api = {
                { name = "tests-idempotency", request_host = "idempotency.com", upstream_url = "http://httpbin.org" },
                { name = "tests-idempotency2", request_host = "custom-expiry-idempotency.com", upstream_url = "http://httpbin.org" }
            },
            consumer = {
                { username = "idempotency_test_consumer1" },
                { username = "idempotency_test_consumer2" }
            },
            plugin = {
                { name = "kong-idempotency", config = {}, __api = 1 },
                { name = "kong-idempotency", config = { token_expiry = CUSTOM_TOKEN_EXPIRY }, __api = 2 }
            }
        }
        spec_helper.start_kong()
    end)

    teardown(function ()
        spec_helper.stop_kong()
    end)

    local function prepare_headers()
        default_header = { host = "idempotency.com" }
        default_header["Idempotency-Token"] = DEFAULT_TOKEN
        default_header[constants.HEADERS.CONSUMER_ID] = inserted_fixtures.consumer[1].id
    end

    local function get_dao()
        return spec_helper.get_env().dao_factory.daos.kong_idempotency
    end

    before_each(function ()
        prepare_headers()
        get_dao():drop()
    end)

    local function send_request_through_api(header)
        header = header or default_header
        return http_client.get(PROXY_URL.."/", {}, header)
    end

    local function assert_successful_request(response, status)
        assert.is.equal(200, status)
        assert.is.truthy(response)
    end

    local function assert_blocked_request(response, status)
        assert.is.equal(400, status)
        local parsed_response = cjson.decode(response)
        local expected_message = "Idempotency token already used: "..DEFAULT_TOKEN
        assert.is.equal(parsed_response.message, expected_message)
    end

    context("when idempotency token is not included in the header", function ()
        it("should not treat request as idempotent", function ()
            send_request_through_api({ host = "idempotency.com"})
            local response, status = send_request_through_api({ host = "idempotency.com"})
            assert_successful_request(response, status)
        end)
    end)

    context("when idempotency token does not exist in the database", function ()
        it("should not reject the request", function ()
            local response, status = send_request_through_api()
            assert_successful_request(response, status)
        end)
    end)

    it("should raise error when idempotency token is reused", function ()
        send_request_through_api()
        local response, status = send_request_through_api()
        assert_blocked_request(response, status)
    end)

    local function insert_default_token_with_time(time)
        local inserted = get_dao():insert {
            idempotency_token = DEFAULT_TOKEN,
            consumer_id = inserted_fixtures.consumer[1].id
        }
        get_dao():update { id = inserted.id, created_at = time }
    end

    local function test_for_almost_expiring_token(expiry)
        local current_time = os.time() * MILLIS_IN_SECONDS
        local offset = 10000 -- allow 10 seconds leeway for test to execute
        local boundary_time = current_time - expiry + offset
        insert_default_token_with_time(boundary_time)
        local response, status = send_request_through_api()
        assert_blocked_request(response, status)
    end

    local function test_for_expired_token(expiry)
        local current_time = os.time() * MILLIS_IN_SECONDS
        local expired_time = current_time - expiry - MILLIS_IN_SECONDS
        insert_default_token_with_time(expired_time)
        local response, status = send_request_through_api()
        assert_successful_request(response, status)
    end

    context("when token expiration is not configured", function ()
        context("when token is stored for almost 24 hours", function ()
            it("should still block the request", function ()
                test_for_almost_expiring_token(DAY_IN_MILLIS)
            end)
        end)

        context("when token is stored for more than 24 hours", function ()
            it("should no longer block the request", function ()
                test_for_expired_token(DAY_IN_MILLIS)
            end)
        end)
    end)

    context("when token expiration is configured", function ()
        before_each(function ()
            default_header.host = "custom-expiry-idempotency.com"
        end)

        context("when expiration has not yet elapsed", function ()
            it("should block the request", function ()
                test_for_almost_expiring_token(CUSTOM_TOKEN_EXPIRY)
            end)
        end)

        context("when expiration has elapsed", function ()
            it("should no longer block the request", function ()
                test_for_expired_token(CUSTOM_TOKEN_EXPIRY)
            end)
        end)
    end)

    context("when token is reused after it expired", function ()
        it("should block succeeding requests", function ()
            test_for_expired_token(DAY_IN_MILLIS)
            local response, status = send_request_through_api()
            assert_blocked_request(response, status)
        end)
    end)

    it("should not be case sensitive for header label", function ()
        send_request_through_api()
        default_header["Idempotency-Token"] = nil
        default_header["IdEmPoTeNcY-ToKeN"] = DEFAULT_TOKEN
        local response, status = send_request_through_api(default_header)
        assert_blocked_request(response, status)
    end)

    context("when different consumers uses the same token", function ()
        it("should not block the other request", function ()
            send_request_through_api()
            default_header[constants.HEADERS.CONSUMER_ID] = inserted_fixtures.consumer[2].id
            local response, status = send_request_through_api(default_header)
            assert_successful_request(response, status)
        end)
    end)
end)
