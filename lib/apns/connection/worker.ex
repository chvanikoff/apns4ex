defmodule APNS.Connection.Worker do
  use GenServer
  require Logger

  def start_link(type) do
    GenServer.start_link(__MODULE__, type, [])
  end
  
  def init(type) do
    config = get_config(type)
    ssl_opts = [
      certfile: Path.absname(config.certfile),
      reuse_sessions: false,
      mode: :binary
    ]
    if config.keyfile != nil do
      ssl_opts = ssl_opts
      |> Dict.put(:keyfile, Path.absname(config.keyfile))
    end
    if config.cert_password != nil do
      ssl_opts = ssl_opts
      |> Dict.put(:password, config.cert_password)
    end

    state = %{
      config: config,
      ssl_opts: ssl_opts,
      socket_in: nil,
      socket_out: nil,
      buffer_in: "",
      buffer_out: "",
      counter: 0
    }
    {:ok, state}
  end

  defp get_config(env) do
    certfiles = Application.get_env(:apns, :certfile)
    hosts = [
      dev: [apple: "gateway.sandbox.push.apple.com",
        feedback: "feedback.sandbox.push.apple.com"],
      prod: [apple: "gateway.push.apple.com",
        feedback: "feedback.push.apple.com"],
      test: [apple: Application.get_env(:apns, :test_apple_server),
        feedback: Application.get_env(:apns, :test_feedback_server)]
    ]
    %{certfile:         certfiles[env],
      apple_host:       hosts[env][:apple],
      feedback_host:    hosts[env][:feedback],
      callback_module:  Application.get_env(:apns, :callback_module,  APNS.Callback),
      keyfile:          Application.get_env(:apns, :key_file,         nil),
      cert_password:    Application.get_env(:apns, :cert_password,    nil),
      timeout:          Application.get_env(:apns, :timeout,          30000),
      feedback_timeout: Application.get_env(:apns, :feedback_timeout, 1200),
      reconnect_after:  Application.get_env(:apns, :reconnect_after,  500)}
  end
end
