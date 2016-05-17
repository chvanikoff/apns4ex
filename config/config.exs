use Mix.Config

config :apns,
  callback_module:  APNS.Callback,
  timeout:          60,
  support_old_ios:  true,
  pools: [
    test: [
      env: :dev,
      certfile: {:apns, Path.expand("../priv/certs/dev.pem", __DIR__)},
      pool_size: 10,
      pool_max_overflow: 0 # WARNING: more than zero overflow seems bad!
    ]
  ]
