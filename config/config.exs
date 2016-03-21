use Mix.Config

config :apns,
  callback_module:  APNS.Callback,
  timeout:          30,
  feedback_interval: 1200,
  reconnect_after:  1000,
  support_old_ios:  true,
  pools: [
    app1_dev_pool: [
      env: :dev,
      certfile: "/path/to/app1_dev.pem",
      pool_size: 10,
      pool_max_overflow: 5
    ],
    app1_prod_pool: [
      env: :prod,
      certfile: "/path/to/app1_prod.pem",
      pool_size: 100,
      pool_max_overflow: 50
    ],
    app2_dev_pool: [
      env: :dev,
      certfile: "/path/to/app2_dev.pem",
      pool_size: 10,
      pool_max_overflow: 5
    ],
    app2_prod_pool: [
      env: :prod,
      certfile: "/path/to/app12prod.pem",
      pool_size: 100,
      pool_max_overflow: 50
    ]
  ]
