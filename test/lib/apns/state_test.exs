defmodule APNS.StateTest do
  use ExUnit.Case

  alias APNS.State

  @payload_min_size 38

  test "get adds merged application defaults with APNS.Configuration defaults and Application level config" do
    configuration = State.get([])

    assert configuration.buffer_apple == ""
    assert configuration.buffer_feedback == ""
    assert configuration.counter == 0
    refute configuration.queue == nil

    assert configuration.config.timeout == 60
    assert configuration.config.feedback_interval == 1200
    assert configuration.config.reconnect_after == 700
    assert configuration.config.support_old_ios == true
    assert configuration.config.callback_module == APNS.Callback
    assert configuration.config.payload_limit == 256
    assert configuration.ssl_opts == [mode: :binary, reuse_sessions: false]
  end

  test "state can override config with pool specific config" do
    configuration = State.get(
      timeout: 12,
      feedback_interval: 3312,
      reconnect_after: 30,
      callback_module: __MODULE__,
      support_old_ios: false,
      reuse_sessions: true,
      mode: :text,
      certfile: "my cert file",
      cert_password: "my cart password",
      keyfile: "my keyfile"
    )

    assert configuration.config.timeout == 12
    assert configuration.config.feedback_interval == 3312
    assert configuration.config.reconnect_after == 30
    assert configuration.config.support_old_ios == false
    assert configuration.config.callback_module == __MODULE__
    assert configuration.config.payload_limit == 2048
    assert Keyword.fetch!(configuration.ssl_opts, :reuse_sessions) == true
    assert Keyword.fetch!(configuration.ssl_opts, :mode) == :text
    assert Keyword.fetch!(configuration.ssl_opts, :certfile) =~ "/my cert file"
    assert Keyword.fetch!(configuration.ssl_opts, :password) == 'my cart password'
    assert Keyword.fetch!(configuration.ssl_opts, :keyfile) =~ "/my keyfile"
  end
end
