defmodule APNS.Sender do
  require Logger

  def send_package(socket, packet) do
    result = :ssl.send(socket, [packet])

    case result do
      :ok ->
        APNS.Logger.debug("success sending ssl package")
      {:error, reason} ->
        APNS.Logger.error("error #{reason} sending ssl package")
    end

    result
  end

  def connect_socket(host, port, opts, timeout_seconds) do
    address = "#{host}:#{port}"

    case :ssl.connect(host, port, opts, timeout_seconds * 1000) do
      {:ok, socket} ->
        APNS.Logger.debug("successfully connected to #{address}")
        {:ok, socket}
      {:error, reason} ->
        APNS.Logger.error("failed to connect to push socket #{address}, reason given: #{inspect(reason)}")
        {:error, {:connection_failed, address}}
    end
  end

  def close(nil), do: nil
  def close(socket) do
    :ssl.close(socket)
  end
end
