defmodule APNS.FeedbackHandlerTest do
  use ExUnit.Case

  alias APNS.FeedbackHandler
  alias APNS.FakeSender

  import ExUnit.CaptureLog

  @moduletag :capture_log

  setup do
    state = %{
      config: %{
        callback_module: APNS.Callback,
        feedback_host: "feedback.apple",
        feedback_port: 2196,
        timeout: 9
      },
      socket_feedback: "socket",
      ssl_opts: [reuse_sessions: false]
    }

    {:ok, %{
      state: state,
      token: "1becf2320bcd26819f96d2d75d58b5e81b11243286bc8e21f54c374aa44a9155"
    }}
  end

  test "connect calls close before connecting", %{state: state} do
    output = capture_log(fn -> FeedbackHandler.connect(state, FakeSender) end)
    assert output =~ ~s(APNS.FakeSender.close)
    assert output =~ ~s(APNS.FakeSender.connect_socket)
  end

  test "connect connects to configured host", %{state: state} do
    output = capture_log(fn -> FeedbackHandler.connect(state, FakeSender) end)
    assert output =~ ~s(APNS.FakeSender.connect_socket/4)
    assert output =~ ~s(host: 'feedback.apple')
    assert output =~ ~s(port: 2196)
    assert output =~ ~s(opts: [])
    assert output =~ ~s(timeout: 9)
  end

  test "connect returns ok if connection succeeded", %{state: state} do
    assert {:ok, %{config: %{feedback_host: "feedback.apple"}}} = FeedbackHandler.connect(state, FakeSender)
  end

  test "connect returns error if connection failed", %{state: state} do
    result = FeedbackHandler.connect(state, APNS.FakeSenderConnectFail)
    assert result == {:error, {:connection_failed, "feedback.apple:2196"}}
  end

  test "handle_response calls callback with token", %{state: state, token: token} do
    state = Map.put(state, :buffer_feedback, feedback_frame(token))

    output = capture_log(fn -> FeedbackHandler.handle_response(state, "socket", "") end)
    assert output =~ ~s("[APNS] Feedback received for token #{String.upcase(token)})
  end

  test "handle_response iterates", %{state: state} do
    buffer = <<
      feedback_frame("1becf2320bcd26819f96d2d75d58b5e81b11243286bc8e21f54c374aa44a9155") :: binary,
      feedback_frame("2becf2320bcd26819f96d2d75d58b5e81b11243286bc8e21f54c374aa44a9155") :: binary,
      feedback_frame("3becf2320bcd26819f96d2d75d58b5e81b11243286bc8e21f54c374aa44a9155") :: binary
    >>
    state = Map.put(state, :buffer_feedback, buffer)

    output = capture_log(fn -> FeedbackHandler.handle_response(state, "socket", "") end)
    assert output =~ ~s("[APNS] Feedback received for token 1BECF2320BCD26819F96D2D75D58B5E81B11243286BC8E21F54C374AA44A9155)
    assert output =~ ~s("[APNS] Feedback received for token 2BECF2320BCD26819F96D2D75D58B5E81B11243286BC8E21F54C374AA44A9155)
    assert output =~ ~s("[APNS] Feedback received for token 3BECF2320BCD26819F96D2D75D58B5E81B11243286BC8E21F54C374AA44A9155)
  end

  defp feedback_frame(token) do
    time = 1458749245
    token_length = 32
    string_token = String.upcase(token)
    {:ok, <<binary_token :: 32-binary>>} = Base.decode16(string_token)

    <<time :: 32, token_length :: 16, binary_token :: size(token_length)-binary>>
  end
end
