defmodule APNS.SslConfigurationTest do
  use ExUnit.Case

  alias APNS.SslConfiguration

  test "get defaults can be overriden" do
    configuration = SslConfiguration.get(reuse_sessions: "foo", mode: "bar")
    assert Keyword.fetch!(configuration, :reuse_sessions) == "foo"
    assert Keyword.fetch!(configuration, :mode) == "bar"
  end

  test "get adds certfile to ssl_opts if given" do
    configuration = SslConfiguration.get(certfile: "/some/absolute/path")
    assert Keyword.fetch!(configuration, :certfile) == "/some/absolute/path"
  end

  test "get adds certfile relative to priv to ssl_opts if given as tuple" do
    configuration = SslConfiguration.get(certfile: {:apns, "certs/dev.pem"})
    assert Keyword.fetch!(configuration, :certfile) =~ "/_build/test/lib/apns/priv/certs/dev.pem"
  end

  test "get adds cert password as char list to ssl_opts if given" do
    configuration = SslConfiguration.get(cert_password: "secret")
    assert Keyword.fetch!(configuration, :password) == 'secret'
  end
end
