# APNS

The library was inspired by [Apns4erl](https://github.com/inaka/apns4erl)

## Warning

The older version of the library is available in `0.0.x-stable` branch

## Installation

  1. Add apns to your list of dependencies in mix.exs:

        def deps do
          [{:apns, "~> 0.9.1"}]
        end

  2. Ensure apns is started before your application:

        def application do
          [applications: [:apns]]
        end

## Usage

Config the APNS app and define pools

```elixir
config :apns,
  # Here goes "global" config applied as default to all pools started if not overwritten by pool-specific value
  callback_module:    APNS.Callback,
  timeout:            30,
  feedback_interval:  1200,
  support_old_ios:    true,
  expiry:    60,
  # Here are pools configs. Any value from "global" config can be overwritten in any single pool config
  pools: [
    # app1_dev_pool is the pool_name
    app1_dev_pool: [
      env: :dev,
      pool_size: 10,
      pool_max_overflow: 0,
      # and this is overwritten config key
      certfile: "/path/to/app1_dev.pem"
    ],
    app1_prod_pool: [
      env: :prod,
      certfile: "/path/to/app1_prod.pem",
      pool_size: 100,
      pool_max_overflow: 0
    ],
  ]
```

### Config keys

| Name              | Default value | Description                                                                                                      |
|:------------------|:--------------|:-----------------------------------------------------------------------------------------------------------------|
| cert              | nil           | Plaintext APNS certfile content (not needed if `certfile` is specified)                                          |
| certfile          | nil           | Path to APNS certificate file or a tuple like `{:my_app, "certs/cert.pem"}`                                      |
|                   |               | which will use a path relative to the `priv` folder of the given application (not needed if `cert` is specified) |
| cert_password     | nil           | APNS certificate password (if any)                                                                               |
| key               | nil           | Plaintext APNS keyfile content (not needed if `keyfile` is specified)                                            |
| keyfile           | nil           | Path to APNS keyfile (not needed if `key` is specified)                                                          |
| callback_module   | APNS.Callback | This module will receive all error and feedback messages from APNS                                               |
| timeout           | 30            | Connection timeout in seconds                                                                                    |
| feedback_interval | 1200          | The app will check Apple feedback server every `feedback_interval` seconds                                       |
| support_old_ios   | true          | Push notifications are limited by 256 bytes (2kb if false), this option can be changed per message individually  |
| expiry            | 60            | Seconds Apple will re-try to deliver the push notification*                                                      |
| pools             | []            | List of pools to start                                                                                           |

\* It should be noted that Apple will always try to deliver the message at least once. If it takes longer to send the message to Apple than the expiry offset it will still be delivered.

### Pool keys

| Pool key          | Description                                                                  |
|:------------------|:-----------------------------------------------------------------------------|
| env               | :dev for Apple sandbox push server or :prod for Apple production push server |
| pool_size         | Maximum pool size                                                            |
| pool_max_overflow | Maximum number of workers created if pool is empty*                          |

\* WARNING: According to our tests a overflow other then zero is bad.

All pools defined in config will be started automatically

From here and now you can start pushing your PNs via APNS.push/2 and APNS.push/3:
```Elixir
message = APNS.Message.new
message = message
|> Map.put(:token, "0000000000000000000000000000000000000000000000000000000000000000")
|> Map.put(:alert, "Hello world!")
|> Map.put(:badge, 42)
|> Map.put(:extra, %{
  "var1" => "val1",
  "var2" => "val2"
})
APNS.push :app1_dev_pool, message
```
or
```Elixir
APNS.push :app1_prod_pool, "0000000000000000000000000000000000000000000000000000000000000000", "Hello world!"
```

## Handling APNS errors and feedback

You can define a callback handler module via config param `callback_module`. The module should implement 2 functions:

* `error/2` which receives `%APNS.Error{}` and `token`
* `feedback/1` which receives `%APNS.Feedback{}`

```elixir
  defmodule APNS.Callback do
    def error(error = %APNS.Error{}, token) do
      # handle error
    end

    def feedback(feedback = %APNS.Feedback{}) do
      # handle feedback
    end
  end
```


## Structs

- %APNS.Message{}
```elixir
defstruct [
  id: nil,
  expiry: 60,
  token: "",
  content_available: nil,
  alert: "",
  badge: nil,
  sound: "default",
  mutable_content: nil,
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
- %APNS.Message.Loc{}
```elixir
defstruct [
  title: "",
  body: "",
  title_loc_key: nil,
  title_loc_args: nil,
  action_loc_key: nil,
  loc_key: "",
  loc_args: [],
  launch_image: nil
]
```

## Contribute

    git clone git@github.com:chvanikoff/apns4ex.git
    # update config/config.exs with the path to your cert (do not use your live cert)
    mix test
