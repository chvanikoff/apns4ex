defmodule APNSTest do
  use ExUnit.Case

  import ExUnit.CaptureLog
  import APNS.TestHelper

  @moduletag :capture_log

  setup do
    message =
      APNS.Message.new(23)
      |> Map.put(:token, "1becf2320bcd26819f96d2d75d58b5e81b11243286bc8e21f54c374aa44a9155")
      |> Map.put(:alert, "Lorem ipsum dolor sit amet, consectetur adipisicing elit")

    {:ok, %{message: message}}
  end

  test "APNS starts all the pools from config" do
    for {pool, _conf} <- Application.get_env(:apns, :pools) do
      assert {:ready, _, _, _} = :poolboy.status(String.to_atom("APNS.Pool.#{to_string(pool)}"))
    end
  end

  @tag :real
  test "push/2 pushes message to worker", %{message: message} do
    output = capture_log(fn -> assert :ok = APNS.push(:test, message) end)
    assert_log output, "23:1becf2 sending message"
  end
end
