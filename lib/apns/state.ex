defmodule APNS.State do
  def get(options) do
    {:ok, queue_pid} = APNS.Queue.start_link

    %{
      config: APNS.Configuration.get(options),
      ssl_opts: APNS.SslConfiguration.get(options),
      socket_feedback: nil,
      socket_apple: nil,
      buffer_feedback: "",
      buffer_apple: "",
      queue: queue_pid,
      counter: 0
    }
  end
end
