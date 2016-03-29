defmodule APNS.Queue do
  def start_link do
    Agent.start_link(fn -> [] end)
  end

  def add(pid, %APNS.Message{} = new_message) do
    Agent.update(pid, fn(messages) -> [new_message | messages] end)
  end

  def messages_after(pid, failed_id) do
    pid
    |> Agent.get_and_update(fn(messages) -> {messages, []} end)
    |> Enum.take_while(fn(message) -> message.id != failed_id end)
  end

  def clear(pid) do
    Agent.update(pid, fn(_) -> [] end)
  end
end
