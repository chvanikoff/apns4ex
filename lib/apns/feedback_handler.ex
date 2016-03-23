defmodule APNS.FeedbackHandler do
  require Logger

  def connect(%{config: config, ssl_opts: opts} = state, sender \\ APNS.Sender) do
    sender.close(state.socket_feedback)
    host = to_char_list(config.feedback_host)
    port = config.feedback_port
    opts = Keyword.delete(opts, :reuse_sessions)

    case sender.connect_socket(host, port, opts, config.timeout) do
      {:ok, socket} -> {:ok, %{state | socket_feedback: socket}}
      {:error, reason} -> {:error, reason}
    end
  end

  def handle_response(state, socket, data) do
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
