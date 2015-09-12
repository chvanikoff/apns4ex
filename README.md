# APNS

The library was inspired by [Apns4erl](https://github.com/inaka/apns4erl)

WIP

## Installation

  1. Add apns to your list of dependencies in mix.exs:

        def deps do
          [{:apns, "~> 0.0.1"}]
        end

  2. Ensure apns is started before your application:

        def application do
          [applications: [:apns]]
        end

## Using

1. Config the APNS app

You can provide config as `key: value` to use the same value for both envs or `key: [dev: dev_value, prod: prod_value]` to use different values for :dev and :prod env

- Required APNS config will only include paths to certificates:
```elixir
config :apns,
  certfile: [
    dev: "/path/to/dev_cert.pem",
    prod: "/path/to/prod_cert.pem"
  ]
```
- Optional config is the following:
```elixir
config :apns,
  callback_module:  APNS.Callback,
  keyfile:          nil,
  cert_password:    nil,
  timeout:          30000,
  feedback_timeout: 1200,
  reconnect_after:  1000
```

2. Start a :dev (for Apple sandbox server) or :prod (for Apple prod server) worker:

```elixir
{:ok, pid} = APNS.start :dev
```

3. Start pushing your PNs via APNS.push/1 and APNS.push/3:
```Elixir
message = %APNS.Message.new
message = message
|> Map.put(:token, "0000000000000000000000000000000000000000000000000000000000000000")
|> Map.put(:alert, "Hello world!")
|> Map.put(:badge, 42)
|> Map.put(:extra, %{
  "var1" => "val1",
  "var2" => "val2"
})
APNS.push pid, message
```
or
```Elixir
APNS.push pid, "0000000000000000000000000000000000000000000000000000000000000000", "Hello world!"
```

## Handling APNS errors and feedback

You can define callback handler module via config param `callback_module`, the module should implement 2 functions: `error/1` and `feedback/1`. These functions will be called when APNS responds with error or feedback to the app. `%APNS.Error` and `%APNS.Feedback` structs are passed to the functions accordingly.

## Structs

- %APNS.Message{}
```elixir
defstruct [
  id: nil,
  expiry: 86400000,
  token: "",
  content_available: nil,
  alert: "",
  badge: nil,
  sound: "default",
  priority: 10,
  extra: [],
  support_old_ios: nil
]
```
- %APNS.Error{}
```elixir
defstruct [
  message_id: nil,
  status: nil,
  error: nil
]
```
- %APNS.Feedback{}
```elixir
defstruct [
  time: nil,
  token: nil
]
```