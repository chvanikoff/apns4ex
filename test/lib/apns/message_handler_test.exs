defmodule APNS.MessageHandlerTest do
  use ExUnit.Case

  alias APNS.MessageHandler
  alias APNS.FakeSender

  import ExUnit.CaptureLog

  @moduletag :capture_log

  setup do
    {:ok, queue_pid} = APNS.Queue.start_link()

    state = %{
      config: %{
        callback_module: APNS.Callback,
        payload_limit: 2048,
        reconnect_after: 3,
        apple_host: "host.apple",
        apple_port: 2195,
        timeout: 10
      },
      socket_apple: "socket",
      queue: queue_pid,
      counter: 0,
      ssl_opts: %{}
    }
    token = String.duplicate("0", 64)
    message =
      %APNS.Message{}
      |> Map.put(:token, token)
      |> Map.put(:alert, "Lorem ipsum dolor sit amet, consectetur adipisicing elit")
      |> Map.put(:id, 23)

    {:ok, %{
      queue_pid: queue_pid,
      apple_success_buffer: <<0 :: 8, 0 :: 8, "1337" :: binary>>,
      state: state,
      message: message,
      token: token
    }}
  end

  test "connect calls close before connecting", %{state: state} do
    output = capture_log(fn -> MessageHandler.connect(state, FakeSender) end)
    assert output =~ ~s(APNS.FakeSender.close)
    assert output =~ ~s(APNS.FakeSender.connect_socket)
  end

  test "connect connects to configured host", %{state: state} do
    output = capture_log(fn -> MessageHandler.connect(state, FakeSender) end)
    assert output =~ ~s(APNS.FakeSender.connect_socket/4)
    assert output =~ ~s(host: 'host.apple')
    assert output =~ ~s(port: 2195)
    assert output =~ ~s(opts: %{})
    assert output =~ ~s(timeout: 10)
  end

  test "connect returns ok if connection succeeded", %{state: state} do
    assert {:ok, %{config: %{apple_host: "host.apple"}}} = MessageHandler.connect(state, FakeSender)
  end

  test "connect returns error if connection failed", %{state: state} do
    result = MessageHandler.connect(state, APNS.FakeSenderConnectFail)
    assert result == {:error, {:connection_failed, "host.apple:2195"}}
  end

  test "push calls error callback if token is invalid size", %{state: state, message: message} do
    message = Map.put(message, :token, String.duplicate("0", 63))
    output = capture_log(fn -> MessageHandler.push(message, state) end)
    assert output =~ ~s([APNS] Error "Invalid token size" for message 23)
  end

  test "push calls error callback if payload is too big", %{state: state, message: message} do
    state = put_in(state, [:config, :payload_limit], 10)
    output = capture_log(fn -> MessageHandler.push(message, state) end)
    assert output =~ ~s([APNS] Error "Invalid payload size" for message 23)
  end

  @tag :pending # shouldn't this pass? See APNS.Payload.to_json
  test "push calls error callback if payload size can be set per message", %{state: state, message: message} do
    message = Map.put(message, :support_old_ios, true)
    message = Map.put(message, :alert, String.duplicate("0", 2000))
    output = capture_log(fn -> MessageHandler.push(message, state) end)
    assert output =~ ~s([APNS] Error "Invalid payload size" for message 23)
  end

  test "push sends payload to Apple", %{state: state, message: message, token: token, queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.push(message, state, APNS.FakeSender) end)
    assert output =~ ~s(APNS.FakeSender.send_package/4)
    assert output =~ ~s(token: "#{token}")
    assert output =~ ~s(alert: "Lorem ipsum dolor sit amet)
    assert output =~ ~s(queque: #{inspect(queue_pid)})
  end

  test "push reconnects after configured amount of pushes", %{state: state, message: message} do
    state = MessageHandler.push(message, state, FakeSender)
    state = MessageHandler.push(message, state, FakeSender)
    state = MessageHandler.push(message, state, FakeSender)
    output = capture_log(fn -> MessageHandler.push(message, state, FakeSender) end)
    assert output =~ ~s([APNS] 3 messages sent, reconnecting)
    assert output =~ ~s(APNS.FakeSender.close/)
    assert output =~ ~s(APNS.FakeSender.connect_socket)
  end

  test "push counts number of pushes", %{state: state, message: message} do
    state = MessageHandler.push(message, state, FakeSender)
    state = MessageHandler.push(message, state, FakeSender)
    assert state.counter == 2
  end

  test "handle_response calls error callback if status byte is 0", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(0, queue_pid), "socket", "") end)
    assert output =~ ~s([APNS] Error "No errors encountered" for message "1234")
  end

  test "handle_response calls error callback if status byte is 1", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(1, queue_pid), "socket", "") end)
    assert output =~ ~s([APNS] Error "Processing error" for message "1234")
  end

  test "handle_response calls error callback if status byte is 2", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(2, queue_pid), "socket", "") end)
    assert output =~ ~s([APNS] Error "Missing device token" for message "1234")
  end

  test "handle_response calls error callback if status byte is 3", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(3, queue_pid), "socket", "") end)
    assert output =~ ~s([APNS] Error "Missing topic" for message "1234")
  end

  test "handle_response calls error callback if status byte is 4", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(4, queue_pid), "socket", "") end)
    assert output =~ ~s([APNS] Error "Missing payload" for message "1234")
  end

  test "handle_response calls error callback if status byte is 5", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(5, queue_pid), "socket", "") end)
    assert output =~ ~s([APNS] Error "Invalid token size" for message "1234")
  end

  test "handle_response calls error callback if status byte is 6", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(6, queue_pid), "socket", "") end)
    assert output =~ ~s([APNS] Error "Invalid topic size" for message "1234")
  end

  test "handle_response calls error callback if status byte is 7", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(7, queue_pid), "socket", "") end)
    assert output =~ ~s([APNS] Error "Invalid payload size" for message "1234")
  end

  test "handle_response calls error callback if status byte is 8", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(8, queue_pid), "socket", "") end)
    assert output =~ ~s([APNS] Error "Invalid token" for message "1234")
  end

  test "handle_response calls error callback if status byte is 10", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(10, queue_pid), "socket", "") end)
    assert output =~ ~s([APNS] Error "Shutdown" for message "1234")
  end

  test "handle_response calls error callback if status byte is 255", %{queue_pid: queue_pid} do
    output = capture_log(fn -> MessageHandler.handle_response(response_state(255, queue_pid), "socket", "") end)
    assert output =~ ~s/[APNS] Error "None (unknown)" for message "1234"/
  end

  test "handle_response retries messages later in queue", %{queue_pid: queue_pid} do
    message1 = %APNS.Message{id: 1}
    message2 = %APNS.Message{id: "1234"}
    message3 = %APNS.Message{id: 3}
    message4 = %APNS.Message{id: 4}
    Agent.update(queue_pid, fn(_) -> [message4, message3, message2, message1] end)

    MessageHandler.handle_response(response_state(8, queue_pid), "socket", "", self())

    refute_receive {_, %APNS.Message{id: 1}}
    refute_receive {_, %APNS.Message{id: "1234"}}
    assert_receive {_, %APNS.Message{id: 3}}
    assert_receive {_, %APNS.Message{id: 4}}
  end

  test "handle_response returns state if rest is blank", %{queue_pid: queue_pid} do
    input_state = response_state(8, queue_pid)
    state = MessageHandler.handle_response(input_state, "socket", "", self())

    assert state == input_state
  end

  test "handle_response iterates over packages until rest is blank", %{queue_pid: queue_pid} do
    state = response_state(6, queue_pid)
    package1 = apple_buffer(8)
    package2 = apple_buffer(7)
    data = <<package1 :: binary, package2 :: binary>>
    output = capture_log(fn -> MessageHandler.handle_response(state, "socket", data) end)

    assert output =~ ~s([APNS] Error "Invalid topic size" for message "1234")
    assert output =~ ~s([APNS] Error "Invalid token" for message "1234")
    assert output =~ ~s([APNS] Error "Invalid payload size" for message "1234")
  end

  @tag :pending # should we support this case?
  test "handle_response iteration works with error response after success", %{queue_pid: queue_pid, apple_success_buffer: apple_success_buffer} do
    state = %{buffer_apple: apple_success_buffer, config: %{callback_module: APNS.Callback}, queue: queue_pid}
    package1 = apple_buffer(8)
    package2 = apple_buffer(7)
    data = <<package1 :: binary, package2 :: binary>>
    output = capture_log(fn -> MessageHandler.handle_response(state, "socket", data) end)

    assert output =~ ~s([APNS] Error "Invalid token" for message "1234")
    assert output =~ ~s([APNS] Error "Invalid payload size" for message "1234")
  end

  @tag :pending # should we support this case?
  test "handle_response iteration works with success response after error", %{queue_pid: queue_pid, apple_success_buffer: apple_success_buffer} do
    state = response_state(6, queue_pid)
    package1 = apple_buffer(8)
    package2 = apple_success_buffer
    package3 = apple_buffer(7)
    data = <<package1 :: binary, package2 :: binary, package3 :: binary>>
    output = capture_log(fn -> MessageHandler.handle_response(state, "socket", data) end)

    assert output =~ ~s([APNS] Error "Invalid topic size" for message "1234")
    assert output =~ ~s([APNS] Error "Invalid token" for message "1234")
    assert output =~ ~s([APNS] Error "Invalid payload size" for message "1234")
  end

  defp response_state(status_code, queue_pid) do
    %{
      buffer_apple: apple_buffer(status_code),
      config: %{callback_module: APNS.Callback},
      queue: queue_pid
    }
  end

  defp apple_buffer(status_code) do
    <<8 :: 8, status_code :: 8, "1234" :: binary>>
  end
end
