local Migrations = {
    {
        name = "2015-12-21-172400_init_kongidempotency",
        up = function(options, dao_factory)
            return dao_factory:execute_queries [[
                CREATE TABLE IF NOT EXISTS kong_idempotency(
                    id uuid,
                    consumer_id uuid,
                    idempotency_token uuid,
                    created_at timestamp,
                    PRIMARY KEY (id)
                );

                CREATE INDEX IF NOT EXISTS ON kong_idempotency(idempotency_token);
                CREATE INDEX IF NOT EXISTS kong_idempotency_consumer_id ON kong_idempotency(consumer_id);
            ]]
        end,
        down = function(options, dao_factory)
            return dao_factory:execute_queries [[
                DROP TABLE kong_idempotency;
            ]]
        end
    }
}

return Migrations
