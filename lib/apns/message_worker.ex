defmodule APNS.MessageWorker do
  use Connection
  require Logger

  @payload_max_old 256
  @payload_max_new 2048
  @invalid_payload_size_code 7

  def start_link(pool_conf) do
    Connection.start_link(__MODULE__, pool_conf, [])
  end

  def send(pid, message) do
    Connection.call(pid, {:send, message})
  end

  def init(pool_conf) do
    state = APNS.State.get(pool_conf)
    {:connect, :init, state}
  end

  # -- server

  def connect(_, %{config: config, ssl_opts: opts} = state, sender \\ APNS.Sender) do
    host = to_char_list(config.apple_host)
    port = config.apple_port

    case sender.connect_socket(host, port, opts, config.timeout) do
      {:ok, socket} -> {:ok, %{state | socket_apple: socket, counter: 0}}
      {:error, _} -> {:backoff, 1000, state}
    end
  end

  def disconnect({type, reason}, %{socket_apple: socket} = state) do
    :ok = :ssl.close(socket)
    Logger.error("Connection #{inspect(type)}: #{inspect(reason)}")

    {:connect, :reconnect, %{state | socket_apple: nil}}
  end

  def handle_call(_, _, %{socket_apple: nil} = state) do
    {:reply, {:error, :closed}, state}
  end

  def handle_call({:send, %APNS.Message{} = message}, _, %{socket_apple: _socket} = state, sender \\ APNS.Sender, retrier \\ APNS) do
    case push(message, state, sender, retrier) do
      {:ok, state} ->
        {:reply, :ok, state}
      {:error, reason, state} ->
        Logger.info("[APNS] reconnecting worker #{inspect(self())} due to conection error #{inspect(reason)}")
        {:disconnect, {:error, reason}, {:error, reason}, state}
    end
  end

  def handle_info({:ssl_closed, socket}, %{socket_apple: socket} = state) do
    {:connect, {:error, "ssl_closed"}, %{state | socket_apple: nil}}
  end

  def handle_info({:ssl, socket, data}, %{socket_apple: socket} = state, retrier \\ APNS) do
    {:noreply, handle_response(state, socket, data, retrier)}
  end

  defp push(%APNS.Message{token: token} = message, state, _sender, _retrier) when byte_size(token) != 64 do
    APNS.Error.new(message.id, 5) |> state.config.callback_module.error(token)
    {:ok, state}
  end

  defp push(%APNS.Message{} = message, %{config: config, socket_apple: socket, queue: queue} = state, sender, retrier) do
    limit = case message.support_old_ios do
      nil -> config.payload_limit
      true -> @payload_max_old
      false -> @payload_max_new
    end

    case APNS.Payload.build_json(message, limit) do
      {:error, :payload_size_exceeded} ->
        APNS.Error.new(message.id, @invalid_payload_size_code) |> state.config.callback_module.error()
        {:ok, state}

      payload ->
        binary_payload = APNS.Package.to_binary(message, payload)
        case sender.send_package(socket, binary_payload) do
          :ok ->
            Logger.debug("[APNS] success sending #{message.id} to #{message.token}")

            if state.counter >= state.config.reconnect_after do
              Logger.debug("[APNS] #{state.counter} messages sent, reconnecting")
              connect(:reconnect, state, sender) # use Connection API?
            end

            {:ok, %{state | queue: [message | queue], counter: state.counter + 1}}

          {:error, reason} ->
            if message.retry_count >= 10 do
              Logger.error("[APNS] #{message.retry_count}th error (#{reason}) sending #{message.id} to #{message.token} message will not be delivered")
            else
              Logger.warn("[APNS] error (#{reason}) sending #{message.id} to #{message.token} retrying…")
              retrier.send(state.pool, Map.put(message, :retry_count, message.retry_count + 1))
            end

            {:error, reason, %{state | queue: [], counter: 0}}
        end
    end
  end

  defp handle_response(state, socket, data, retrier) do
    case <<state.buffer_apple :: binary, data :: binary>> do
      <<8 :: 8, status :: 8, message_id :: integer-32, rest :: binary>> ->
        APNS.Error.new(message_id, status) |> state.config.callback_module.error()

        for message <- messages_after(state.queue, message_id) do
          retrier.send(state.pool, message)
        end

        state = %{state | queue: []}

        case rest do
          "" -> state
          _ -> handle_response(%{state | buffer_apple: ""}, socket, rest, retrier)
        end

      buffer ->
        %{state | buffer_apple: buffer}
    end
  end

  defp messages_after(queue, failed_id) do
    Enum.take_while(queue, fn(message) -> message.id != failed_id end)
  end
end
