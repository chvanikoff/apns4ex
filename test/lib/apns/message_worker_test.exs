defmodule APNS.MessageWorkerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  alias APNS.MessageWorker

  @moduletag :capture_log

  @tag :real
  test "push calls GenServer" do
    worker = :poolboy.checkout(:"APNS.Pool.test")
    message =
      APNS.Message.new(23)
      |> Map.put(:token, "1becf2320bcd26819f96d2d75d58b5e81b11243286bc8e21f54c374aa44a9155")
      |> Map.put(:alert, "Lorem ipsum dolor sit amet, consectetur adipisicing elit")

    output = capture_log(fn -> assert :ok = MessageWorker.push(worker, message) end)
    assert output =~ ~s([APNS] success sending 23 to 1becf2320bcd26819f96d2d75d58b5e81b11243286bc8e21f54c374aa44a9155)
  end
end
