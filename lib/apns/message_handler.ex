defmodule APNS.MessageHandler do
  require Logger

  @payload_max_old 256
  @payload_max_new 2048
  @invalid_payload_size_code 7

  def connect(%{config: config, ssl_opts: opts} = state, sender \\ APNS.Sender) do
    sender.close(state.socket_apple)
    host = to_char_list(config.apple_host)
    port = config.apple_port

    case sender.connect_socket(host, port, opts, config.timeout) do
      {:ok, socket} -> {:ok, %{state | socket_apple: socket, counter: 0}}
      {:error, reason} -> {:error, reason}
    end
  end

  def push(_message, _state, sender \\ APNS.Sender)

  def push(%APNS.Message{token: token} = message, state, _sender) when byte_size(token) != 64 do
    APNS.Error.new(message.id, 5) |> state.config.callback_module.error()
    state
  end

  def push(%APNS.Message{} = message, %{config: config, socket_apple: socket, queue: queue} = state, sender) do
    limit = case message.support_old_ios do
      nil -> config.payload_limit
      true -> @payload_max_old
      false -> @payload_max_new
    end

    case APNS.Payload.build_json(message, limit) do
      {:error, :payload_size_exceeded} ->
        APNS.Error.new(message.id, @invalid_payload_size_code) |> state.config.callback_module.error()
        state

      payload ->
        binary_payload = APNS.Package.to_binary(message, payload)
        case sender.send_package(socket, binary_payload) do
          :ok ->
            state = %{state | queue: [message | queue]}
            Logger.debug("[APNS] success sending #{message.id} to #{message.token}")
          {:error, reason} ->
            state = %{state | queue: []}
            Logger.error("[APNS] error (#{reason}) sending #{message.id} to #{message.token}")
        end

        if state.counter >= state.config.reconnect_after do
          Logger.debug("[APNS] #{state.counter} messages sent, reconnecting")
          connect(state, sender)
        end

        %{state | counter: state.counter + 1}
    end
  end

  def handle_response(state, socket, data, worker_pid \\ self()) do
    case <<state.buffer_apple :: binary, data :: binary>> do
      <<8 :: 8, status :: 8, message_id :: integer-32, rest :: binary>> ->
        APNS.Error.new(message_id, status) |> state.config.callback_module.error()

        for message <- messages_after(state.queue, message_id) do
          GenServer.cast(worker_pid, message)
        end

        state = %{state | queue: []}

        case rest do
          "" -> state
          _ -> handle_response(%{state | buffer_apple: ""}, socket, rest)
        end

      buffer ->
        %{state | buffer_apple: buffer}
    end
  end

  defp messages_after(queue, failed_id) do
    Enum.take_while(queue, fn(message) -> message.id != failed_id end)
  end
end
