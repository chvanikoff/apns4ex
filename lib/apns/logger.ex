defmodule APNS.Logger do
  require Logger

  def debug(message, text), do: output(message, text) |> Logger.debug()
  def debug(text), do: output(text) |> Logger.debug()

  def info(message, text), do: output(message, text) |> Logger.info()
  def info(text), do: output(text) |> Logger.info()

  def warn(message, text), do: output(message, text) |> Logger.warn()
  def warn(text), do: output(text) |> Logger.warn()

  def error(message, text), do: output(message, text) |> Logger.error()
  def error(text), do: output(text) |> Logger.error()

  defp output(message, text) do
    prefix() <> " #{message.id}:#{String.slice(message.token, 0..5)} " <> text
  end

  defp output(text) do
    prefix() <> " " <> text
  end

  defp prefix do
    "[APNS] #{inspect(self())}"
  end
end
