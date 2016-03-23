defmodule APNS.Configuration do
  defstruct [
    timeout: 30,
    feedback_interval: 1200,
    reconnect_after: 1100,
    callback_module: APNS.Callback,
    support_old_ios: true,
    payload_limit: 256,
    apple_host: "gateway.sandbox.push.apple.com",
    apple_port: 2195,
    feedback_host: "feedback.sandbox.push.apple.com",
    feedback_port: 2196
  ]

  @payload_max_old 256
  @payload_max_new 2048

  def get(options) do
    global = Application.get_all_env(:apns) |> Enum.into(%{})
    options = Enum.into(options, %{})

    %__MODULE__{}
    |> struct(global)
    |> struct(options)
    |> payload_limit()
    |> apple_host(options)
    |> feedback_host(options)
  end

  defp payload_limit(%{support_old_ios: true} = config), do: Map.put(config, :payload_limit, @payload_max_old)
  defp payload_limit(%{support_old_ios: false} = config), do: Map.put(config, :payload_limit, @payload_max_new)

  defp apple_host(config, %{env: :prod}), do: Map.put(config, :apple_host, "gateway.push.apple.com")
  defp apple_host(config, _options), do: Map.put(config, :apple_host, "gateway.sandbox.push.apple.com")

  defp feedback_host(config, %{env: :prod}), do: Map.put(config, :feedback_host, "feedback.push.apple.com")
  defp feedback_host(config, _options), do: Map.put(config, :feedback_host, "feedback.sandbox.push.apple.com")
end
