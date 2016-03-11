defmodule APNS.Worker do
  use GenServer
  require Logger

  @payload_max_old 256
  @payload_max_new 2048

  def start_link(pool_conf) do
    GenServer.start_link(__MODULE__, pool_conf, [])
  end

  def init(pool_conf) do
    config = get_config(pool_conf)
    ssl_opts = [
      reuse_sessions: false,
      mode: :binary
    ]
    if config.certfile != nil do
      ssl_opts = ssl_opts
      |> Dict.put(:certfile, certfile_path(config.certfile))
    end
    if config.cert != nil do
      ssl_opts = case :public_key.pem_decode(config.cert) do
                   [{:Certificate, certDer, _}] -> ssl_opts |> Dict.put(:cert, certDer)
                   _ -> ssl_opts
                 end
    end
    if config.key != nil do
      ssl_opts = case :public_key.pem_decode(config.key) do
                   [{:RSAPrivateKey, keyDer, _}] -> ssl_opts |> Dict.put(:key, { :RSAPrivateKey, keyDer})
                   _ -> ssl_opts
                 end
    end
    if config.keyfile != nil do
      ssl_opts = ssl_opts
      |> Dict.put(:keyfile, Path.absname(config.keyfile))
    end
    if config.cert_password != nil do
      ssl_opts = ssl_opts
      |> Dict.put(:password, to_char_list(config.cert_password))
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
        :timer.sleep(timeout)
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
        :timer.sleep(timeout)
        {:stop, {:connection_failed, address}, state}
    end
  end

  def handle_info({:ssl_closed, socket}, %{socket_apple: socket} = state) do
    Logger.debug "[APNS] Apple socket was closed"
    # In case there's some error it will be caught at the following function and the server will stop
    handle_info(:connect_apple, %{state | socket_apple: nil})
  end

  def handle_info({:ssl_closed, socket}, %{socket_feedback: socket} = state) do
    interval = state.config.feedback_interval * 1000
    Logger.debug "[APNS] Feedback socket was closed. Reconnect in #{state.config.feedback_interval} seconds."
    :erlang.send_after(interval, self, :connect_feedback)
    {:noreply, %{state | socket_feedback: nil}}
  end

  def handle_info({:ssl, socket, data}, %{socket_apple: socket} = state) do
    case <<state.buffer_apple :: binary, data :: binary>> do
      <<8 :: 8, status :: 8, msg_id :: binary-4, rest :: binary>> ->
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
      <<time :: 32, length :: 16, token :: size(length)-binary, rest :: binary>> ->
        %APNS.Feedback{time: time, token: Base.encode16(token)}
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

  def handle_call(%APNS.Message{token: token} = msg, _from, state) when byte_size(token) != 64 do
    APNS.Error.new(msg.id, 5)
    |> state.config.callback_module.error()
    {:reply, :ok, state}
  end
  def handle_call(%APNS.Message{} = msg, _from, %{config: config} = state) do
    limit = case msg.support_old_ios do
      nil -> config.payload_limit
      true -> @payload_max_old
      false -> @payload_max_new
    end
    case build_payload(msg, limit) do
      {:error, :payload_size_exceeded} ->
        APNS.Error.new(msg.id, 7)
        |> state.config.callback_module.error()
        {:reply, :ok, state}
      payload ->
        send_message(state.socket_apple, msg, payload)
        if (state.counter >= state.config.reconnect_after) do
          Logger.debug "[APNS] #{state.counter} messages sent, reconnecting"
          send self, :connect_apple
        end
        {:reply, :ok, %{state | counter: state.counter + 1}}
    end
  end

  def build_payload(msg, payload_limit) do
    payload = %{aps: %{}}

    if msg.sound do
      payload = put_in(payload[:aps][:sound], msg.sound)
    end

    if msg.category != nil do
      payload = put_in(payload[:aps][:category], msg.category)
    end

    if msg.badge != nil do
      payload = put_in(payload[:aps][:badge], msg.badge)
    end

    if msg.content_available != nil do
      payload = put_in(payload[:aps][:'content-available'], msg.content_available)
    end

    if msg.extra != [] do
      payload = Map.merge(payload, msg.extra)
    end

    if is_binary(msg.alert) do
      payload = put_in(payload[:aps][:alert], msg.alert)
    else
      payload = put_in(payload[:aps][:alert], format_loc(msg.alert))
    end

    encode(payload, payload_limit)
  end

  defp encode(payload, payload_limit) do
    json = Poison.encode!(payload)

    length_diff = byte_size(json) - payload_limit
    length_alert = case payload.aps.alert do
      %{body: body} -> byte_size(body)
      str when is_binary(str) -> byte_size(str)
    end

    cond do
      length_diff <= 0 -> json
      length_diff >= length_alert -> {:error, :payload_size_exceeded}
      true ->
        payload = put_in(payload[:aps][:alert], truncate(payload.aps.alert, length_alert - length_diff))
        Poison.encode!(payload)
    end
  end

  defp truncate(%{body: string} = alert, size) do
    %{alert | body: truncate(string, size)}
  end

  defp truncate(string, size) when is_binary(string) do
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
    token_bin = msg.token |> Base.decode16!(case: :mixed)
    frame = <<
      1                  :: 8,
      32                 :: 16,
      token_bin          :: binary,
      2                  :: 8,
      byte_size(payload) :: 16,
      payload            :: binary,
      3                  :: 8,
      4                  :: 16,
      msg.id             :: 32,
      4                  :: 8,
      4                  :: 16,
      msg.expiry         :: 32,
      5                  :: 8,
      1                  :: 16,
      msg.priority       :: 8
    >>
    packet = <<
      2                 ::  8,
      byte_size(frame)  ::  32,
      frame             ::  binary
    >>

    result = :ssl.send(socket, [packet])
    case result do
      :ok -> Logger.debug("[APNS] success sent #{msg.id} to #{msg.token}")
      {:error, reason} -> Logger.error("[APNS] error (#{reason}) sending #{msg.id} to #{msg.token}")
    end

    result
  end

  defp ssl_close(nil), do: nil
  defp ssl_close(socket), do: :ssl.close(socket)

  defp certfile_path(string) when is_binary(string) do
    Path.expand(string)
  end

  defp certfile_path({app_name, path}) when is_atom(app_name) do
    Path.expand(path, :code.priv_dir(app_name))
  end

  defp get_config(pool_conf) do
    opts = [
      cert: nil,
      key: nil,
      certfile: nil,
      cert_password: nil,
      keyfile: nil,
      callback_module: APNS.Callback,
      timeout: 30,
      feedback_interval: 1200,
      reconnect_after: 1000,
      support_old_ios: true
    ]
    global_conf = Application.get_all_env :apns
    config = Enum.reduce opts, %{}, fn({key, default}, map) ->
      val = case pool_conf[key] do
        nil -> Keyword.get(global_conf, key, default)
        v -> v
      end
      Map.put(map, key, val)
    end

    hosts = [
      dev: [apple: [host: "gateway.sandbox.push.apple.com", port: 2195],
        feedback: [host: "feedback.sandbox.push.apple.com", port: 2196]],
      prod: [apple: [host: "gateway.push.apple.com", port: 2195],
        feedback: [host: "feedback.push.apple.com", port: 2196]]
    ]
    env = pool_conf[:env]
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
