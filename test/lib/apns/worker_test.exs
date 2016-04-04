defmodule APNS.WorkerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  alias APNS.Worker

  @moduletag :capture_log

  @tag :real
  test "push calls GenServer" do
    worker = :poolboy.checkout(:"APNS.Pool.test")
    message =
      %APNS.Message{}
      |> Map.put(:token, "1becf2320bcd26819f96d2d75d58b5e81b11243286bc8e21f54c374aa44a9155")
      |> Map.put(:alert, "Lorem ipsum dolor sit amet, consectetur adipisicing elit")
      |> Map.put(:id, 23)

    output = capture_log(fn -> assert :ok = Worker.push(worker, message) end)
    assert output =~ ~s([APNS] success sending 23 to 1becf2320bcd26819f96d2d75d58b5e81b11243286bc8e21f54c374aa44a9155)
  end
end
