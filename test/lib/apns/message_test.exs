defmodule APNS.MessageTest do
  use ExUnit.Case
  alias APNS.Message

  test "new generates id random if not given" do
    id1 = Message.new().id
    id2 = Message.new().id

    assert is_number(id1)
    refute id1 == id2
  end

  test "new sets the given id" do
    assert Message.new(123).id == 123
  end

  test "new sets generated at timestamp" do
    assert Message.new().generated_at >= :os.system_time(:seconds)
  end
end
