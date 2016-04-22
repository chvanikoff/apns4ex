defmodule APNS.ConfigurationTest do
  use ExUnit.Case

  alias APNS.Configuration

  test "get adds merged application defaults with APNS.Configuration defaults and Application level config" do
    configuration = Configuration.get([])

    assert configuration.timeout == 60
    assert configuration.feedback_interval == 1200
    assert configuration.support_old_ios == true
    assert configuration.callback_module == APNS.Callback
    assert configuration.payload_limit == 256
    assert configuration.expiry == 60
  end

  test "get defaults can be overriden" do
    configuration = Configuration.get([
      timeout: 9,
      feedback_interval: 7,
      callback_module: __MODULE__,
      expiry: 12
    ])

    assert configuration.timeout == 9
    assert configuration.feedback_interval == 7
    assert configuration.callback_module == __MODULE__
    assert configuration.expiry == 12
  end

  test "get sets Apple addresses to sandbox when given env :dev" do
    configuration = Configuration.get(env: :dev)

    assert configuration.apple_host == "gateway.sandbox.push.apple.com"
    assert configuration.apple_port == 2195
    assert configuration.feedback_host == "feedback.sandbox.push.apple.com"
    assert configuration.feedback_port == 2196
  end

  test "get sets Apple addresses to live when given env :prod" do
    configuration = Configuration.get(env: :prod)

    assert configuration.apple_host == "gateway.push.apple.com"
    assert configuration.apple_port == 2195
    assert configuration.feedback_host == "feedback.push.apple.com"
    assert configuration.feedback_port == 2196
  end

  test "get sets max payload to low limit if support_old_ios is true" do
    configuration = Configuration.get(support_old_ios: true, env: :dev)
    assert configuration.payload_limit == 256
  end

  test "get sets max payload to hight limit if support_old_ios is false" do
    configuration = Configuration.get(support_old_ios: false, env: :dev)
    assert configuration.payload_limit == 2048
  end
end
