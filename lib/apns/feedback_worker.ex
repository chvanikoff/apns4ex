defmodule APNS.FeedbackWorker do
  use Connection

  def start_link(pool_conf) do
    Connection.start_link(__MODULE__, pool_conf, [])
  end

  def init(pool_conf) do
    state = APNS.State.get(pool_conf)
    {:connect, :init, state}
  end

  # -- server

  def connect(_, _state, sender \\ APNS.Sender)

  def connect(:reconnect, %{config: %{feedback_interval: interval}} = state, _sender) do
    APNS.Logger.info("closed feedback connection, reconnecting in #{interval}s")
    {:backoff, interval * 1000, state}
  end

  def connect(_, %{config: config, ssl_opts: opts} = state, sender) do
    host = to_char_list(config.feedback_host)
    port = config.feedback_port
    opts = Keyword.delete(opts, :reuse_sessions)

    case sender.connect_socket(host, port, opts, config.timeout) do
      {:ok, socket} ->
        APNS.Logger.info("successfully opened connection to feedback service")
        {:ok, %{state | socket_feedback: socket}}
      {:error, reason} ->
        APNS.Logger.info("error (#{inspect(reason)}) opening connection to feedback service")
        {:backoff, 1000, state}
    end
  end

  def disconnect({type, reason}, %{socket_feedback: socket} = state, sender \\ APNS.Sender) do
    :ok = sender.close(socket)
    APNS.Logger.error("connection #{inspect(type)}: #{inspect(reason)}")

    {:connect, :reconnect, %{state | socket_feedback: nil}}
  end

  def handle_info({:ssl_closed, socket}, %{socket_feedback: socket} = state) do
    {:connect, :reconnect, %{state | socket_feedback: nil}}
  end

  def handle_info({:ssl, socket, data}, %{socket_feedback: socket} = state) do
    {:noreply, handle_response(state, socket, data)}
  end

  defp handle_response(state, socket, data) do
    case <<state.buffer_feedback :: binary, data :: binary>> do
      <<time :: 32, length :: 16, token :: size(length)-binary, rest :: binary>> ->
        %APNS.Feedback{time: time, token: Base.encode16(token)}
        |> state.config.callback_module.feedback()
        state = %{state | buffer_feedback: ""}

        case rest do
          "" -> state
          _ -> handle_response(state, socket, rest)
        end

      buffer ->
        %{state | buffer_feedback: buffer}
    end
  end
end
