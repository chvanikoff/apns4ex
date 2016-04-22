defmodule APNS.MessageWorker do
  use Connection

  @payload_max_old 256
  @payload_max_new 2048
  @invalid_payload_size_code 7

  def start_link(pool_conf) do
    Connection.start_link(__MODULE__, pool_conf, [])
  end

  def send(pid, message) do
    APNS.Logger.debug(message, "sending message")
    Connection.cast(pid, {:send, message})
  end

  def init(pool_conf) do
    state = APNS.State.get(pool_conf)
    APNS.Logger.debug("init worker")
    {:connect, :init, state}
  end

  # -- server
  def connect(_, %{config: config, ssl_opts: opts} = state, sender \\ APNS.Sender) do
    host = to_char_list(config.apple_host)
    port = config.apple_port

    case sender.connect_socket(host, port, opts, config.timeout) do
      {:ok, socket} ->
        APNS.Logger.debug("successfully connected to socket")
        {:ok, %{state | socket_apple: socket, counter: 0}}
      {:error, _} ->
        APNS.Logger.warn("unable to connect to socket, backing off")
        {:backoff, 1000, state}
    end
  end

  def disconnect({type, reason}, %{socket_apple: socket} = state) do
    :ok = :ssl.close(socket)
    APNS.Logger.debug("socket disconnected #{inspect(type)}: #{inspect(reason)}")

    {:connect, :reconnect, %{state | socket_apple: nil}}
  end

  def handle_cast(_, %{socket_apple: nil} = state) do
    APNS.Logger.debug("tried to send data on non-existing socket")
    {:noreply, state}
  end

  def handle_cast({:send, %APNS.Message{} = message}, %{socket_apple: _socket} = state, sender \\ APNS.Sender, retrier \\ APNS) do
    APNS.Logger.debug(message, "handling call :send")

    case push(message, state, sender, retrier) do
      {:ok, state} ->
        APNS.Logger.debug(message, "handle call :send received :ok")
        {:noreply, state}
      {:error, reason, state} ->
        APNS.Logger.warn(message, "reconnecting worker due to connection error #{inspect(reason)}")
        {:disconnect, {:error, reason}, state}
    end
  end

  def handle_info({:ssl_closed, socket}, %{socket_apple: socket} = state) do
    APNS.Logger.debug("ssl socket closed, returning :connect")
    {:connect, {:error, "ssl_closed"}, %{state | socket_apple: nil}}
  end

  def handle_info({:ssl_closed, _socket}, state) do
    APNS.Logger.debug("received message about already closed ssl socket")
    {:noreply, state}
  end

  def handle_info(_, state, retrier \\ APNS)

  def handle_info({:ssl, socket, data}, %{socket_apple: socket} = state, retrier) do
    APNS.Logger.debug("received :ssl callback, handling response…")
    {:noreply, handle_response(state, socket, data, retrier)}
  end

  def handle_info({:ssl, _old_socket, data}, %{socket_apple: socket} = state, retrier) do
    APNS.Logger.debug("received :ssl callback, on old socket handling response…")
    handle_info({:ssl, socket, data}, state, retrier)
  end

  defp push(%APNS.Message{token: token} = message, state, _sender, _retrier) when byte_size(token) != 64 do
    APNS.Error.new(message.id, 5) |> state.config.callback_module.error(token)
    {:ok, state}
  end

  defp push(%APNS.Message{token: token} = message, %{config: config, socket_apple: socket, queue: queue} = state, sender, retrier) do
    limit = case message.support_old_ios do
      nil -> config.payload_limit
      true -> @payload_max_old
      false -> @payload_max_new
    end

    case APNS.Payload.build_json(message, limit) do
      {:error, :payload_size_exceeded} ->
        APNS.Error.new(message.id, @invalid_payload_size_code) |> state.config.callback_module.error(token)
        {:ok, state}

      payload ->
        APNS.Logger.debug(message, "message's payload looks good")
        binary_payload = APNS.Package.to_binary(message, payload)
        case sender.send_package(socket, binary_payload) do
          :ok ->
            APNS.Logger.debug(message, "success sending")
            {:ok, %{state | queue: [message | queue], counter: state.counter + 1}}

          {:error, reason} ->
            if message.retry_count >= 10 do
              APNS.Logger.error(message, "#{message.retry_count}th error #{reason} message will not be delivered")
            else
              APNS.Logger.warn(message, "#{reason} retrying…")
              retrier.push(state.pool, Map.put(message, :retry_count, message.retry_count + 1))
            end

            {:error, reason, %{state | queue: [], counter: 0}}
        end
    end
  end

  defp handle_response(%{queue: queue} = state, socket, data, retrier) do
    APNS.Logger.debug("handling response")

    case <<state.buffer_apple :: binary, data :: binary>> do
      <<8 :: 8, status :: 8, message_id :: integer-32, rest :: binary>> ->
        token = message_token(queue, message_id)
        APNS.Error.new(message_id, status) |> state.config.callback_module.error(token)

        for message <- messages_after(queue, message_id) do
          APNS.Logger.debug(message, "resending after bad message #{message_id}")
          retrier.push(state.pool, message)
        end

        APNS.Logger.info("done resending messages after bad message #{message_id}")

        state = %{state | queue: []}

        case rest do
          "" -> state
          _ -> handle_response(%{state | buffer_apple: ""}, socket, rest, retrier)
        end

      buffer ->
        APNS.Logger.error("ignoring un-documented Apple write on socket")
        %{state | buffer_apple: buffer}
    end
  end

  defp message_token([], message_id) do
    APNS.Logger.debug("message #{message_id} not found in empty queue")
    "unknown token"
  end

  defp message_token(queue, message_id) do
    case Enum.find(queue, fn(message) -> message.id == message_id end) do
      nil ->
        APNS.Logger.error("message #{message_id} not found in queue #{inspect(queue)}")
        "unknown token"
      message ->
        message.token
    end
  end

  defp messages_after(queue, failed_id) do
    Enum.take_while(queue, fn(message) -> message.id != failed_id end)
  end
end
