defmodule APNSTest do
  use ExUnit.Case
  import ExUnit.CaptureLog

  @moduletag :capture_log

  test "APNS starts all the pools from config" do
    for {pool, _conf} <- Application.get_env(:apns, :pools) do
      assert {:ready, _, _, _} = :poolboy.status(APNS.pool_name(pool))
    end
  end

  @tag :real
  test "push/2 pushes message to worker" do
    message =
      APNS.Message.new(23)
      |> Map.put(:token, "1becf2320bcd26819f96d2d75d58b5e81b11243286bc8e21f54c374aa44a9155")
      |> Map.put(:alert, "Lorem ipsum dolor sit amet, consectetur adipisicing elit")

    output = capture_log(fn -> assert :ok = APNS.push(:test, message) end)
    assert output =~ ~s([APNS] success sending 23 to 1becf2320bcd26819f96d2d75d58b5e81b11243286bc8e21f54c374aa44a9155)
  end
end
