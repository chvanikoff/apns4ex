defmodule APNS.Worker do
  use Connection
  require Logger

  def start_link(pool_conf) do
    Connection.start_link(__MODULE__, pool_conf, [])
  end

  def push(pid, message) do
    Connection.call(pid, {:send, message})
  end

  def init(pool_conf) do
    state = APNS.State.get(pool_conf)
    {:connect, :init, state}
  end

  # -- server

  def connect(_, state) do
    APNS.MessageHandler.connect(state)
  end

  def disconnect(info, %{socket_apple: socket} = state) do
    :ok = :ssl.close(socket)

    case info do
      {:close, from} ->
        Connection.reply(from, :ok)
      {:error, :closed} ->
        Logger.error("Connection closed")
      {:error, reason} ->
        reason = :inet.format_error(reason)
        Logger.error("Connection error: #{inspect(reason)}")
    end

    {:connect, :reconnect, %{state | socket_apple: nil}}
  end

  def handle_call(_, _, %{socket_apple: nil} = state) do
    {:reply, {:error, :closed}, state}
  end

  def handle_call({:send, message}, _, %{socket_apple: _socket} = state) do
    case APNS.MessageHandler.push(message, state) do
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

  def handle_info({:ssl, socket, data}, %{socket_apple: socket} = state) do
    {:noreply, APNS.MessageHandler.handle_response(state, socket, data)}
  end
end
