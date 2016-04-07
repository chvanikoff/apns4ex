defmodule APNS.FeedbackWorker do
  use Connection
  require Logger

  def start_link(pool_conf) do
    Connection.start_link(__MODULE__, pool_conf, [])
  end

  def init(pool_conf) do
    state = APNS.State.get(pool_conf)
    {:connect, :init, state}
  end

  # -- server

  def connect(:reconnect, %{config: %{feedback_interval: interval}} = state) do
    {:backoff, interval * 1000, state}
  end

  def connect(_, state) do
    APNS.FeedbackHandler.connect(state)
  end

  def disconnect(info, %{socket_feedback: socket} = state) do
    :ok = :ssl.close(socket)

    case info do
      {:close, from} ->
        Connection.reply(from, :ok)
      {:error, :closed} ->
        Logger.warn("[APNS] Connection closed")
      {:error, reason} ->
        reason = :inet.format_error(reason)
        Logger.warn("[APNS] Connection error: #{inspect(reason)}")
    end

    {:connect, :reconnect, %{state | socket_feedback: nil}}
  end

  def handle_info({:ssl_closed, socket}, %{socket_feedback: socket, config: %{feedback_interval: interval}} = state) do
    Logger.info("[APNS] closed connection, reconnecting in #{interval}s")
    {:connect, :reconnect, %{state | socket_feedback: nil}}
  end

  def handle_info({:ssl, socket, data}, %{socket_feedback: socket} = state) do
    {:noreply, APNS.FeedbackHandler.handle_response(state, socket, data)}
  end
end
