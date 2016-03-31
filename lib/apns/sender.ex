defmodule APNS.Sender do
  require Logger

  def send_package(socket, packet) do
    result = :ssl.send(socket, [packet])

    case result do
      :ok ->
        Logger.debug("[APNS] success sending ssl package")
      {:error, reason} ->
        Logger.error("[APNS] error (#{reason}) sending ssl package")
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

  def close(nil), do: nil
  def close(socket) do
    :ssl.close(socket)
  end
end
