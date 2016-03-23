defmodule APNS.QueueTest do
  use ExUnit.Case

  setup do
    {:ok, pid} = APNS.Queue.start_link()
    {:ok, %{pid: pid}}
  end

  test "queue is initialized as an empty list", %{pid: pid} do
    assert messages(pid) == []
  end

  test "add adds a message to the queue", %{pid: pid} do
    message1 = %APNS.Message{id: 123}
    message2 = %APNS.Message{id: 123}

    APNS.Queue.add(pid, message1)
    assert messages(pid) == [message1]

    APNS.Queue.add(pid, message2)
    assert messages(pid) == [message2, message1]
  end

  test "get_resends returns messages sent after the failed message and clears queue", %{pid: pid} do
    message1 = %APNS.Message{id: 1}
    message2 = %APNS.Message{id: 2}
    message3 = %APNS.Message{id: 3}
    message4 = %APNS.Message{id: 4}

    Agent.update(pid, fn(_) -> [message4, message3, message2, message1] end)

    assert APNS.Queue.messages_after(pid, 2) == [message4, message3]
    assert messages(pid) == []
  end

  defp messages(pid) do
    Agent.get(pid, fn(messages) -> messages end)
  end
end
