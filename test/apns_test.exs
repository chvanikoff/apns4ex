defmodule APNSTest do
  use ExUnit.Case

  test "APNS starts all the pools from config" do
    for {pool, _conf} <- Application.get_env(:apns, :pools) do
      assert {:ready, _, _, _} = :poolboy.status(APNS.pool_name(pool))
    end
  end
end
