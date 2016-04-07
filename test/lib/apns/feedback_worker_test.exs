defmodule APNS.FeedbackWorkerTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias APNS.FeedbackWorker
  alias APNS.FakeSender

  @moduletag :capture_log

  setup do
    config = %{
      feedback_interval: 23,
      feedback_port: 2196,
      timeout: 9,
      feedback_host: "feedback.apple",
      callback_module: APNS.Callback
    }
    state = %{
      config: config,
      socket_feedback: %{},
      ssl_opts: []
    }
    token = "1becf2320bcd26819f96d2d75d58b5e81b11243286bc8e21f54c374aa44a9155"

    {:ok, state: state, token: token}
  end

  @tag :real
  test "start_link opens ssl connection to Apple feedback service" do
    output = capture_log(fn ->
      start_worker()
      :timer.sleep 2000
    end)

    assert output =~ ~s([APNS] successfully opened connection to feedback service)
  end

  test "connect backoffs when receiving :reconnect", %{state: state} do
    assert {:backoff, 23000, state} == FeedbackWorker.connect(:reconnect, state)
  end

  test "connect returns ok when connection is successful", %{state: state} do
    output = capture_log(fn ->
      assert {:ok, state} == FeedbackWorker.connect(:anything, state, FakeSender)
    end)

    assert output =~ ~s(APNS.FakeSender.connect_socket/4)
    assert output =~ ~s(host: 'feedback.apple')
    assert output =~ ~s(port: 2196)
    assert output =~ ~s(opts: [])
    assert output =~ ~s(timeout: 9)
  end

  test "connect returns :backoff when connection is unsuccessful", %{state: state} do
    assert {:backoff, 1000, state} == FeedbackWorker.connect(:anything, state, APNS.FakeSenderConnectFail)
  end

  test "disconnect reconnects and removes socket from state", %{state: state} do
    assert {:connect, :reconnect, %{state | socket_feedback: nil}} == FeedbackWorker.disconnect({:type, :reason}, state, FakeSender)
  end

  test "disconnect reconnects", %{state: state} do
    assert {:connect, :reconnect, %{state | socket_feedback: nil}} == FeedbackWorker.disconnect({:type, :reason}, state, FakeSender)
  end

  test "disconnect closes connection", %{state: state} do
    output = capture_log(fn -> FeedbackWorker.disconnect({:type, :reason}, state, FakeSender) end)
    assert output =~ "APNS.FakeSender.close/1"
  end

  test "handle_info reconnects when received :ssl_close", %{state: state} do
    result = FeedbackWorker.handle_info({:ssl_closed, state.socket_feedback}, state)
    assert {:connect, :reconnect, %{state | socket_feedback: nil}} == result
  end

  test "handle_response calls callback with token", %{state: state, token: token} do
    state = Map.put(state, :buffer_feedback, feedback_frame(token))

    output = capture_log(fn -> FeedbackWorker.handle_info({:ssl, state.socket_feedback, ""}, state) end)
    assert output =~ ~s("[APNS] Feedback received for token #{String.upcase(token)})
  end

  test "handle_response iterates", %{state: state} do
    buffer = <<
      feedback_frame("1becf2320bcd26819f96d2d75d58b5e81b11243286bc8e21f54c374aa44a9155") :: binary,
      feedback_frame("2becf2320bcd26819f96d2d75d58b5e81b11243286bc8e21f54c374aa44a9155") :: binary,
      feedback_frame("3becf2320bcd26819f96d2d75d58b5e81b11243286bc8e21f54c374aa44a9155") :: binary
    >>
    state = Map.put(state, :buffer_feedback, buffer)

    output = capture_log(fn -> FeedbackWorker.handle_info({:ssl, state.socket_feedback, ""}, state) end)
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

  defp start_worker do
    {:ok, worker} = FeedbackWorker.start_link([
      env: :dev,
      certfile: {:apns, "certs/dev.pem"},
      pool: :test,
      cert_password: '4epVi6VwfjvlrBZYLsoy4fAC4noef5Y'
    ])
    worker
  end
end
