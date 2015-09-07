defmodule APNSTest do
  use ExUnit.Case
  doctest APNS

  test "APNS start/stop for :dev and :prod env works correctly"do
    for env <- [:dev, :prod] do
      {:ok, pid} = APNS.start(env)
      assert Process.alive? pid
      :ok = APNS.stop(pid)
      refute Process.alive? pid
    end
  end
end
