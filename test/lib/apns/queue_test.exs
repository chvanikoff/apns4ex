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
    msg1 = %APNS.Message{id: 123}
    msg2 = %APNS.Message{id: 123}

    APNS.Queue.add(pid, msg1)
    assert messages(pid) == [msg1]

    APNS.Queue.add(pid, msg2)
    assert messages(pid) == [msg2, msg1]
  end

  test "get_resends returns messages sent after the failed message and clears queue", %{pid: pid} do
    msg1 = %APNS.Message{id: 1}
    msg2 = %APNS.Message{id: 2}
    msg3 = %APNS.Message{id: 3}
    msg4 = %APNS.Message{id: 4}

    Agent.update(pid, fn(_) -> [msg4, msg3, msg2, msg1] end)

    assert APNS.Queue.messages_after(pid, 2) == [msg4, msg3]
    assert messages(pid) == []
  end

  defp messages(pid) do
    Agent.get(pid, fn(messages) -> messages end)
  end
end
