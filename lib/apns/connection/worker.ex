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
      socket_feedback: nil,
      socket_apple: nil,
      buffer_feedback: "",
      buffer_apple: "",
      counter: 0
    }
    send self, :connect_apple
    send self, :connect_feedback
    {:ok, state}
  end

  def handle_info(:connect_apple, %{config: config, ssl_opts: opts} = state) do
    ssl_close(state.socket_apple)
    host = to_char_list(config.apple_host)
    port = config.apple_port
    timeout = config.timeout
    address = "#{config.apple_host}:#{config.apple_port}"
    case :ssl.connect(host, port, opts, timeout) do
      {:ok, socket} ->
        Logger.debug "[APNS] connected to #{address}"
        {:noreply, %{state | socket_apple: socket}}
      {:error, reason} ->
        Logger.error "[APNS] failed to connect #{address}, reason given: #{inspect reason}"
        {:stop, {:connection_failed, address}, state}
    end
  end

  def handle_info(:connect_feedback, %{config: config, ssl_opts: opts} = state) do
    ssl_close(state.socket_feedback)
    host = to_char_list(config.feedback_host)
    port = config.feedback_port
    opts = Keyword.delete(opts, :reuse_sessions)
    timeout = config.timeout
    address = "#{config.feedback_host}:#{config.feedback_port}"
    case :ssl.connect(host, port, opts, timeout) do
      {:ok, socket} ->
        Logger.debug "[APNS] connected to #{address}"
        {:noreply, %{state | socket_feedback: socket}}
      {:error, reason} ->
        Logger.error "[APNS] failed to connect #{address}, reason given: #{inspect reason}"
        {:stop, {:connection_failed, address}, state}
    end
  end

  def handle_info({:ssl_closed, socket}, %{socket_apple: socket} = state) do
    Logger.debug "[APNS] Apple socket was closed"
    # In case there's some error it will be caught at the following function and the server will stop
    handle_info(:connect_apple, %{state | socket_apple: nil})
  end

  def handle_info({:ssl_closed, socket}, %{socket_feedback: socket} = state) do
    timeout = state.config.feedback_timeout
    Logger.debug "[APNS] Feedback socket was closed. Reconnect in #{timeout}s."
    :erlang.send_after(timeout * 1000, self, :connect_feedback)
    {:noreply, %{state | socket_feedback: nil}}
  end

  defp ssl_close(nil), do: nil
  defp ssl_close(socket), do: :ssl.close(socket)

  defp get_config(env) do
    certfiles = Application.get_env(:apns, :certfile)
    hosts = [
      dev: [apple: [host: "gateway.sandbox.push.apple.com", port: 2195],
        feedback: [host: "feedback.sandbox.push.apple.com", port: 2196]],
      prod: [apple: [host: "gateway.push.apple.com", port: 2195],
        feedback: [host: "feedback.push.apple.com", port: 2196]]
    ]
    %{certfile:         certfiles[env],
      apple_host:       hosts[env][:apple][:host],
      apple_port:       hosts[env][:apple][:port],
      feedback_host:    hosts[env][:feedback][:host],
      feedback_port:    hosts[env][:feedback][:port],
      callback_module:  Application.get_env(:apns, :callback_module,  APNS.Callback),
      keyfile:          Application.get_env(:apns, :key_file,         nil),
      cert_password:    Application.get_env(:apns, :cert_password,    nil),
      timeout:          Application.get_env(:apns, :timeout,          30000),
      feedback_timeout: Application.get_env(:apns, :feedback_timeout, 1200),
      reconnect_after:  Application.get_env(:apns, :reconnect_after,  500)}
  end
end
