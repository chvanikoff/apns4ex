defmodule APNS.Worker do
  use GenServer
  require Logger

  def start_link(pool_conf) do
    GenServer.start_link(__MODULE__, pool_conf, [])
  end

  def push(pid, message) do
    GenServer.call(pid, message)
  end

  def init(pool_conf) do
    state = APNS.State.get(pool_conf)
    send(self, :connect_apple)
    send(self, :connect_feedback)
    {:ok, state}
  end

  def handle_info(:connect_apple, %{config: %{timeout: timeout}} = state) do
    case APNS.MessageHandler.connect(state) do
      {:ok, state} ->
        {:noreply, state}
      {:error, reason} ->
        sleep(timeout)
        {:stop, reason, state}
    end
  end

  def handle_info(:connect_feedback, %{config: %{timeout: timeout}} = state) do
    case APNS.FeedbackHandler.connect(state) do
      {:ok, state} ->
        {:noreply, state}
      {:error, reason} ->
        sleep(timeout)
        {:stop, reason, state}
    end
  end

  def handle_info({:ssl_closed, socket}, %{socket_apple: socket} = state) do
    handle_info(:connect_apple, %{state | socket_apple: nil})
  end

  def handle_info({:ssl_closed, socket}, %{socket_feedback: socket, config: %{feedback_interval: interval}} = state) do
    Logger.debug("[APNS] Feedback socket was closed. Reconnect in #{interval} seconds")
    send_after(interval, :connect_feedback)
    {:noreply, %{state | socket_feedback: nil}}
  end

  def handle_info({:ssl, socket, data}, %{socket_apple: socket} = state) do
    {:noreply, APNS.MessageHandler.handle_response(state, socket, data)}
  end

  def handle_info({:ssl, socket, data}, %{socket_feedback: socket} = state) do
    {:noreply, APNS.FeedbackHandler.handle_response(state, socket, data)}
  end

  def handle_call(message, _from, state) do
    case APNS.MessageHandler.push(message, state) do
      {:ok, state} ->
        {:reply, :ok, state}
      {:error, reason, state} ->
        Logger.info("[APNS] stopping worker #{inspect(self())} due to conection error #{inspect(reason)}")
        {:stop, :normal, :ok, state}
    end
  end

  defp sleep(seconds) do
    :timer.sleep(seconds * 1000)
  end

  defp send_after(seconds, message) do
    Process.send_after(self, message, seconds * 1000)
  end
end
