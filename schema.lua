return {
    no_consumer = true,
    fields = {
        say_hello = { type = "boolean", default = true },
        token_expiry = { type= "number", default = 86400000 } -- in miliseconds
    }
}
