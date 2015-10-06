defmodule APNS.Connection.Worker do
  use GenServer
  require Logger

  @payload_max_old 256
  @payload_max_new 2048

  def push(conn, %APNS.Message{} = msg) do
    GenServer.cast(conn, msg)
  end
  

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
    timeout = config.timeout * 1000
    address = "#{config.apple_host}:#{config.apple_port}"
    case :ssl.connect(host, port, opts, timeout) do
      {:ok, socket} ->
        Logger.debug "[APNS] connected to #{address}"
        {:noreply, %{state | socket_apple: socket, counter: 0}}
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
    timeout = config.timeout * 1000
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
    timeout = state.config.feedback_timeout * 1000
    Logger.debug "[APNS] Feedback socket was closed. Reconnect in #{timeout}s."
    :erlang.send_after(timeout, self, :connect_feedback)
    {:noreply, %{state | socket_feedback: nil}}
  end

  def handle_info({:ssl, socket, data}, %{socket_apple: socket} = state) do
    case <<state.buffer_apple :: binary, data :: binary>> do
      <<8 :: 8-unit(1), status :: 8-unit(1), msg_id :: binary-4, rest :: binary>> ->
        APNS.Error.new(msg_id, status)
        |> state.config.callback_module.error()
        case rest do
          "" -> {:noreply, state}
          _ -> handle_info({:ssl, socket, rest}, %{state | buffer_apple: ""})
        end
      buffer ->
        {:noreply, %{state | buffer_apple: buffer}}
    end
  end

  def handle_info({:ssl, socket, data}, %{socket_feedback: socket} = state) do
    case <<state.buffer_feedback :: binary, data :: binary>> do
      <<time :: 8-big-unsigned-integer-unit(4), length :: 8-big-unsigned-integer-unit(2), token :: size(length)-binary, rest :: binary>> ->
        %APNS.Feedback{time: time, token: Hexate.encode(token)}
        |> state.config.callback_module.feedback()
        state = %{state | buffer_feedback: ""}
        case rest do
          "" -> {:noreply, state}
          _ -> handle_info({:ssl, socket, rest}, state)
        end
      buffer ->
        {:noreply, %{state | buffer_feedback: buffer}}
    end
  end

  def handle_cast(%APNS.Message{} = msg, %{config: config} = state) do
    limit = case msg.support_old_ios do
      nil -> config.payload_limit
      true -> @payload_max_old
      false -> @payload_max_new
    end
    case build_payload(msg, limit) do
      {:error, reason} ->
        Logger.warn "[APNS] Failed to build payload, message was not sent. Reason given: #{inspect reason}"
        {:noreply, state}
      payload ->
        send_message(state.socket_apple, msg, payload)
        if (state.counter >= state.config.reconnect_after) do
          Logger.debug "[APNS] #{state.counter} messages sent, reconnecting"
          send self, :connect_apple
        end
        {:noreply, %{state | counter: state.counter + 1}}
    end
  end

  def build_payload(msg, payload_limit) do
    aps = %{
      alert: msg.alert,
      sound: msg.sound
    }
    if msg.badge != nil do
      aps = aps
      |> Map.put(:badge, msg.badge)
    end
    if msg.content_available != nil do
      aps = aps
      |> Map.put(:'content-available', msg.content_available)
    end
    payload = %{aps: aps}
    if msg.extra != [] do
      payload = payload
      |> Map.merge(msg.extra)
    end
    json = Poison.encode! payload
    length_diff = byte_size(json) - payload_limit
    length_alert = case msg.alert do
      %APNS.Message.Loc{body: body} -> byte_size(body)
      str when is_binary(str) -> byte_size(str)
    end
    cond do
      length_diff <= 0 -> json
      length_diff >= length_alert -> {:error, {:payload_size_exceeded, length_diff}}
      true ->
        alert = truncate(msg.alert, length_alert - length_diff)
        unless is_binary(alert) do
          alert = format_loc(alert)
        end
        payload = %{payload | aps: %{aps | alert: alert}}
        Poison.encode! payload
    end
  end

  defp truncate(%APNS.Message.Loc{body: string} = alert, size) do
    %{alert | body: truncate(string, size)}
  end
  defp truncate(string, size) do
    string2 = string <> "…"
    if byte_size(string2) <= size do
      string2
    else
      string = String.slice(string, 0, String.length(string) - 1)
      truncate(string, size)
    end
  end

  defp format_loc(%APNS.Message.Loc{title: title, body: body, title_loc_key: title_loc_key,
                                    title_loc_args: title_loc_args, action_loc_key: action_loc_key,
                                    loc_key: loc_key, loc_args: loc_args,
                                    launch_image: launch_image}) do
    # These are required parameters
    alert = %{title: title, body: body, "loc-key": loc_key, "loc-args": loc_args}
    # Following are optional parameters
    if title_loc_key != nil do
      alert = alert
      |> Map.put(:'title-loc-key', title_loc_key)
    end
    if title_loc_args != nil do
      alert = alert
      |> Map.put(:'title-loc-args', title_loc_args)
    end
    if action_loc_key != nil do
      alert = alert
      |> Map.put(:'action-loc-key', action_loc_key)
    end
    if launch_image != nil do
      alert = alert
      |> Map.put(:'launch-image', launch_image)
    end
    alert
  end
  
  defp send_message(socket, msg, payload) do
    frame = <<
      1                         ::  8,
      32                        ::  16-big,
      Hexate.decode(msg.token)  ::  binary,
      2                         ::  8,
      byte_size(payload)        ::  16-big,
      payload                   ::  binary,
      3                         ::  8,
      4                         ::  16-big,
      msg.id                    ::  4-big-unsigned-integer-unit(8),
      4                         ::  8,
      4                         ::  16-big,
      msg.expiry                ::  4-big-unsigned-integer-unit(8),
      5                         ::  8,
      1                         ::  16-big,
      msg.priority              ::  8
    >>
    packet = <<
      2                 ::  8,
      byte_size(frame)  ::  4-big-unsigned-integer-unit(8),
      frame             ::  binary
    >>
    :ssl.send(socket, [packet])
  end

  defp ssl_close(nil), do: nil
  defp ssl_close(socket), do: :ssl.close(socket)

  defp get_config(env) do
    opts = [
      certfile: nil,
      cert_password: nil,
      keyfile: nil,
      callback_module: APNS.Callback,
      timeout: 30,
      feedback_timeout: 1200,
      reconnect_after: 1000,
      support_old_ios: true
    ]
    config = Enum.reduce opts, %{}, fn({key, default}, map) ->
      val = Application.get_env(:apns, key, default)
      if is_list(val) do
        val = val[env]
      end
      Map.put(map, key, val)
    end

    hosts = [
      dev: [apple: [host: "gateway.sandbox.push.apple.com", port: 2195],
        feedback: [host: "feedback.sandbox.push.apple.com", port: 2196]],
      prod: [apple: [host: "gateway.push.apple.com", port: 2195],
        feedback: [host: "feedback.push.apple.com", port: 2196]]
    ]
    payload_limit = case config.support_old_ios do
      true -> @payload_max_old
      false -> @payload_max_new
    end
    config2 = %{
      payload_limit: payload_limit,
      apple_host:    hosts[env][:apple][:host],
      apple_port:    hosts[env][:apple][:port],
      feedback_host: hosts[env][:feedback][:host],
      feedback_port: hosts[env][:feedback][:port]
    }
    Map.merge(config, config2)
  end
end
