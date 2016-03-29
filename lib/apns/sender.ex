defmodule APNS.Sender do
  require Logger
  alias APNS.Queue

  def send_package(socket, packet, message, queue) do
    result = :ssl.send(socket, [packet])

    case result do
      :ok ->
        Queue.add(queue, message)
        Logger.debug("[APNS] success sending #{message.id} to #{message.token}")
      {:error, reason} ->
        Queue.clear(queue)
        Logger.error("[APNS] error (#{reason}) sending #{message.id} to #{message.token}")
    end

    result
  end

  def connect_socket(host, port, opts, timeout_seconds) do
    address = "#{host}:#{port}"

    case :ssl.connect(host, port, opts, timeout_seconds * 1000) do
      {:ok, socket} ->
        Logger.debug("[APNS] connected to #{address}")
        {:ok, socket}
      {:error, reason} ->
        Logger.error "[APNS] failed to connect to push socket #{address}, reason given: #{inspect(reason)}"
        {:error, {:connection_failed, address}}
    end
  end

  def close(nil) do
    nil
  end

  def close(socket) do
    :ssl.close(socket)
  end
end
