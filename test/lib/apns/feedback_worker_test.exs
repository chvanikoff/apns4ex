defmodule APNS.FeedbackWorkerTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  alias APNS.FeedbackWorker

  @moduletag :capture_log

  @tag :real
  test "start_link opens ssl connection to Apple feedback service" do
    output = capture_log(fn ->
      {:ok, _worker} = FeedbackWorker.start_link([
        env: :dev,
        certfile: {:apns, "certs/dev.pem"},
        pool: :test,
        cert_password: '4epVi6VwfjvlrBZYLsoy4fAC4noef5Y'
      ])
      :timer.sleep 2000
    end)

    assert output =~ ~s([APNS] successfully opened connection to feedback service)
  end
end
