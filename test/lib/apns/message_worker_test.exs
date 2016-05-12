defmodule APNS.MessageWorkerTest do
  use ExUnit.Case

  import ExUnit.CaptureLog
  import APNS.TestHelper

  alias APNS.MessageWorker
  alias APNS.FakeSender
  alias APNS.FakeRetrier

  @moduletag :capture_log

  setup do
    config = %{
      apple_port: 2195,
      timeout: 10,
      apple_host: "host.apple",
      callback_module: APNS.Callback,
      payload_limit: 256
    }
    state = %{
      config: config,
      socket_apple: %{},
      ssl_opts: [],
      counter: 0,
      queue: [],
      pool: :test
    }
    token = "1becf2320bcd26819f96d2d75d58b5e81b11243286bc8e21f54c374aa44a9155"
    message =
      APNS.Message.new(23)
      |> Map.put(:token, token)
      |> Map.put(:alert, "Lorem ipsum dolor sit amet, consectetur adipisicing elit")

    {:ok, state: state, token: token, message: message}
  end

  @tag :real
  test "handle_cast :send calls GenServer", %{token: token} do
    message =
      APNS.Message.new(23)
      |> Map.put(:token, token)
      |> Map.put(:alert, "Lorem ipsum dolor sit amet, consectetur adipisicing elit")

    :ok = MessageWorker.send(self(), message)
    assert_receive {_, {:send, ^message}}
  end

  test "init calls connect with state" do
    config = [
      apple_port: 2196,
      timeout: 9,
      apple_host: "feedback.apple",
      callback_module: APNS.Callback,
      pool: :test
    ]
    assert {:connect, :init, %{config: %APNS.Configuration{}, buffer_apple: ""}} = MessageWorker.init(config)
  end

  test "connect calls close before connecting", %{state: state} do
    output = capture_log(fn -> MessageWorker.connect(:anything, state, FakeSender) end)
    assert output =~ ~s(APNS.FakeSender.connect_socket)
  end

  test "connect connects to configured host", %{state: state} do
    output = capture_log(fn -> MessageWorker.connect(:anything, state, FakeSender) end)
    assert output =~ ~s(APNS.FakeSender.connect_socket/4)
    assert output =~ ~s(host: 'host.apple')
    assert output =~ ~s(port: 2195)
    assert output =~ ~s(opts: [])
    assert output =~ ~s(timeout: 10)
  end

  test "connect returns ok if connection succeeded", %{state: state} do
    assert {:ok, %{config: %{apple_host: "host.apple"}}} = MessageWorker.connect(:anything, state, FakeSender)
  end

  test "connect resets the queue", %{state: state} do
    assert {:ok, %{queue: []}} = MessageWorker.connect(:anything, %{state | queue: [1, 2, 3]}, FakeSender)
  end

  test "connect returns error if connection failed", %{state: state} do
    result = MessageWorker.connect(:anything, state, APNS.FakeSenderConnectFail)
    assert result == {:backoff, 1000, state}
  end

  test "handle_cast :send calls error callback if token is invalid size", %{state: state, message: message} do
    token = String.duplicate("0", 63)
    message = Map.put(message, :token, token)
    output = capture_log(fn ->
      assert MessageWorker.handle_cast({:send, message}, state, FakeSender, FakeRetrier) == {:noreply, state}
    end)
    assert_log output, ~s(error "Invalid token size" for message 23 to #{token})
  end

  test "handle_cast :send calls error callback if payload is too big", %{state: state, message: message} do
    state = put_in(state, [:config, :payload_limit], 10)
    output = capture_log(fn ->
      assert MessageWorker.handle_cast({:send, message}, state, FakeSender, FakeRetrier) == {:noreply, state}
    end)
    assert_log output, ~s(error "Invalid payload size" for message 23 to #{message.token})
  end

  @tag :pending # shouldn't this pass? See APNS.Payload.to_json
  test "handle_cast :send calls error callback if payload size can be set per message", %{state: state, message: message} do
    message = Map.put(message, :support_old_ios, true)
    message = Map.put(message, :alert, String.duplicate("0", 2000))
    output = capture_log(fn -> MessageWorker.handle_cast({:send, message}, state, FakeSender, FakeRetrier) end)
    assert_log output, ~s(error "Invalid payload size" for message 23)
  end

  test "handle_cast :send sends payload to Apple", %{state: state, message: message, token: token} do
    output = capture_log(fn ->
      result = MessageWorker.handle_cast({:send, message}, state, FakeSender, FakeRetrier)
      assert {:noreply, %{queue: [^message], counter: 1}} = result
    end)
    assert output =~ ~s(APNS.FakeSender.send_package/2)
    assert_log output, ~s(23:#{String.slice(token, 0..5)} success sending)
  end

  test "handle_cast :send puts the failed message back on the queue for re-sending", %{state: state, message: message} do
    output = capture_log(fn ->
      result = MessageWorker.handle_cast({:send, message}, state, APNS.FakeSenderSendPackageFail, FakeRetrier)
      assert result == {:disconnect, {:error, "FakeSenderSendPackageFail failed"}, state}
    end)
    assert_log output, ~s(23:#{String.slice(message.token, 0..5)} reconnecting worker due to connection error "FakeSenderSendPackageFail failed")
    assert_log output, ~s(23:#{String.slice(message.token, 0..5)} FakeSenderSendPackageFail failed retrying)
    assert output =~ ~s(APNS.FakeRetrier.push/2 pool: :test)
    assert output =~ ~s(id: 23)
  end

  test "handle_cast :send don't put messages that have failed more than 10 times back for re-sending", %{state: state, message: message} do
    message = Map.put(message, :retry_count, 10)
    output = capture_log(fn ->
      result = MessageWorker.handle_cast({:send, message}, state, APNS.FakeSenderSendPackageFail, FakeRetrier)
      assert result == {:disconnect, {:error, "FakeSenderSendPackageFail failed"}, state}
    end)

    assert_log output, ~s(23:#{String.slice(message.token, 0..5)} 10th error FakeSenderSendPackageFail failed message will not be delivered)
    refute output =~ ~s(APNS.FakeRetrier.push/2 pool: :test)
  end

  test "handle_cast :send counts number of pushes", %{state: state, message: message} do
    {:noreply, state} = MessageWorker.handle_cast({:send, message}, state, FakeSender, FakeRetrier)
    {:noreply, state} = MessageWorker.handle_cast({:send, message}, state, FakeSender, FakeRetrier)
    assert state.counter == 2
  end

  test "handle_info :ssl calls error callback if status byte is 0" do
    output = capture_log(fn -> MessageWorker.handle_info({:ssl, "socket", ""}, response_state(0)) end)
    assert_log output, ~s(error "No errors encountered" for message 1234)
  end

  test "handle_info :ssl calls error callback if status byte is 1" do
    output = capture_log(fn -> MessageWorker.handle_info({:ssl, "socket", ""}, response_state(1)) end)
    assert_log output, ~s(error "Processing error" for message 1234)
  end

  test "handle_info :ssl calls error callback if status byte is 2" do
    output = capture_log(fn -> MessageWorker.handle_info({:ssl, "socket", ""}, response_state(2)) end)
    assert_log output, ~s(error "Missing device token" for message 1234)
  end

  test "handle_info :ssl calls error callback if status byte is 3" do
    output = capture_log(fn -> MessageWorker.handle_info({:ssl, "socket", ""}, response_state(3)) end)
    assert_log output, ~s(error "Missing topic" for message 1234)
  end

  test "handle_info :ssl calls error callback if status byte is 4" do
    output = capture_log(fn -> MessageWorker.handle_info({:ssl, "socket", ""}, response_state(4)) end)
    assert_log output, ~s(error "Missing payload" for message 1234)
  end

  test "handle_info :ssl calls error callback if status byte is 5" do
    output = capture_log(fn -> MessageWorker.handle_info({:ssl, "socket", ""}, response_state(5)) end)
    assert_log output, ~s(error "Invalid token size" for message 1234)
  end

  test "handle_info :ssl calls error callback if status byte is 6" do
    output = capture_log(fn -> MessageWorker.handle_info({:ssl, "socket", ""}, response_state(6)) end)
    assert_log output, ~s(error "Invalid topic size" for message 1234)
  end

  test "handle_info :ssl calls error callback if status byte is 7" do
    output = capture_log(fn -> MessageWorker.handle_info({:ssl, "socket", ""}, response_state(7)) end)
    assert_log output, ~s(error "Invalid payload size" for message 1234)
  end

  test "handle_info :ssl calls error callback if status byte is 8" do
    message1 = APNS.Message.new(1) |> Map.put(:token, "zxcv")
    message2 = APNS.Message.new(1234) |> Map.put(:token, "asdf")
    queue = [message2, message1]

    output = capture_log(fn -> MessageWorker.handle_info({:ssl, "socket", ""}, response_state(8, queue)) end)
    assert_log output, ~s(error "Invalid token" for message 1234 to asdf)
  end

  test "handle_info :ssl calls error callback if status byte is 10" do
    output = capture_log(fn -> MessageWorker.handle_info({:ssl, "socket", ""}, response_state(10)) end)
    assert_log output, ~s(error "Shutdown" for message 1234)
  end

  test "handle_info :ssl calls error callback if status byte is 255" do
    output = capture_log(fn -> MessageWorker.handle_info({:ssl, "socket", ""}, response_state(255)) end)
    assert_log output, ~s(error "None unknown" for message 1234 to unknown token)
  end

  test "handle_info :ssl logs error if message can't be found in queue" do
    message = APNS.Message.new(1)
    output = capture_log(fn -> MessageWorker.handle_info({:ssl, "socket", ""}, response_state(8, [message])) end)
    assert_log output, ~s(message 1234 not found in queue)
  end

  test "handle_info :ssl logs debug if queue is empty" do
    output = capture_log(fn -> MessageWorker.handle_info({:ssl, "socket", ""}, response_state(8)) end)
    assert_log output, ~s(message 1234 not found in empty queue)
  end

  test "handle_info :ssl retries messages later in queue" do
    message1 = APNS.Message.new(1)
    message2 = APNS.Message.new(1234)
    message3 = APNS.Message.new(3)
    message4 = APNS.Message.new(4)
    queue = [message4, message3, message2, message1]

    output = capture_log(fn -> MessageWorker.handle_info({:ssl, "socket", ""}, response_state(8, queue), FakeRetrier) end)
    assert output =~ ~s(APNS.FakeRetrier.push/2 pool: :test)
    assert output =~ ~s(id: 4)
    assert output =~ ~s(id: 3)
    refute output =~ ~s(id: 1234)
    refute output =~ ~s(id: 1)
  end

  test "handle_info :ssl does not retry messages later in queue if bad message is not in queue" do
    message1 = APNS.Message.new(1)
    message2 = APNS.Message.new(2)
    message3 = APNS.Message.new(3)
    message4 = APNS.Message.new(4)
    queue = [message4, message3, message2, message1]

    output = capture_log(fn -> MessageWorker.handle_info({:ssl, "socket", ""}, response_state(8, queue), FakeRetrier) end)
    refute output =~ ~s(APNS.FakeRetrier.push/2 pool: :test)
    refute output =~ ~s(4: resending after bad message 1234)
    refute output =~ ~s(3: resending after bad message 1234)
    refute output =~ ~s(2: resending after bad message 1234)
    refute output =~ ~s(1: resending after bad message 1234)
  end

  test "handle_info :ssl clears queue on error" do
    message1 = APNS.Message.new(1)
    message2 = APNS.Message.new(1234)
    message3 = APNS.Message.new(3)
    queue = [message3, message2, message1]

    assert {:noreply, %{queue: []}} = MessageWorker.handle_info({:ssl, "socket", ""}, response_state(8, queue), FakeRetrier)
  end

  test "handle_info :ssl returns state if rest is blank" do
    input_state = response_state(8)
    {:noreply, state} = MessageWorker.handle_info({:ssl, "socket", ""}, input_state)

    assert state == input_state
  end

  test "handle_info :ssl iterates over packages until rest is blank" do
    state = response_state(6)
    package1 = apple_buffer(8)
    package2 = apple_buffer(7)
    data = <<package1 :: binary, package2 :: binary>>
    output = capture_log(fn -> MessageWorker.handle_info({:ssl, "socket", data}, state) end)

    assert_log output, ~s(error "Invalid topic size" for message 1234)
    assert_log output, ~s(error "Invalid token" for message 1234)
    assert_log output, ~s(error "Invalid payload size" for message 1234)
  end

  @tag :pending # should we support this case?
  test "handle_info :ssl iteration works with error response after success", %{apple_success_buffer: apple_success_buffer} do
    state = %{buffer_apple: apple_success_buffer, config: %{callback_module: APNS.Callback}, queue: []}
    package1 = apple_buffer(8)
    package2 = apple_buffer(7)
    data = <<package1 :: binary, package2 :: binary>>
    output = capture_log(fn -> MessageWorker.handle_info({:ssl, "socket", data}, state) end)

    assert_log output, ~s(error "Invalid token" for message 1234)
    assert_log output, ~s(error "Invalid payload size" for message 1234)
  end

  @tag :pending # should we support this case?
  test "handle_info :ssl iteration works with success response after error", %{apple_success_buffer: apple_success_buffer} do
    state = response_state(6)
    package1 = apple_buffer(8)
    package2 = apple_success_buffer
    package3 = apple_buffer(7)
    data = <<package1 :: binary, package2 :: binary, package3 :: binary>>
    output = capture_log(fn -> MessageWorker.handle_info({:ssl, "socket", data}, state) end)

    assert_log output, ~s(error "Invalid topic size" for message 1234)
    assert_log output, ~s(error "Invalid token" for message 1234)
    assert_log output, ~s(error "Invalid payload size" for message 1234)
  end

  defp response_state(status_code, queue \\ []) do
    %{
      buffer_apple: apple_buffer(status_code),
      socket_apple: "socket",
      config: %{callback_module: APNS.Callback},
      queue: queue,
      pool: :test
    }
  end

  defp apple_buffer(status_code) do
    <<8 :: 8, status_code :: 8, 1234 :: integer-32>>
  end
end
