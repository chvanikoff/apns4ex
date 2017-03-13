defmodule APNS.PayloadTest do
  use ExUnit.Case

  alias APNS.Payload

  @payload_min_size 38

  setup do
    message =
      %APNS.Message{}
      |> Map.put(:token, String.duplicate("0", 64))
      |> Map.put(:alert, String.duplicate("lorem ipsum", 100))
      |> Map.put(:token, "1becf2320bcd26819f96d2d75d58b5e81b11243286bc8e21f54c374aa44a9155")
      |> Map.put(:id, 123)

    {:ok, %{message: message}}
  end

  test "build_json if PN exceeds length of 256 bytes, it still builds proper payload by truncating alert message", %{message: message} do
    message = Map.put(message, :alert, String.duplicate("lorem ipsum", 100))
    payload = Payload.build_json(message, 256)

    assert byte_size(payload) == 256
    assert Poison.decode!(payload)["aps"]["alert"] == "lorem ipsumlorem ipsumlorem ipsumlorem ipsumlorem ipsumlorem ipsumlorem ipsumlorem ipsumlorem ipsumlorem ipsumlorem ipsumlorem ipsumlorem ipsumlorem ipsumlorem ipsumlorem ipsumlorem ipsumlorem ipsumlorem ipsumlorem …"
  end

  test "build_json PN with UTF8-characters is properly truncated", %{message: message} do
    message = Map.put(message, :alert, String.duplicate("ありがとう", 30))
    payload = Payload.build_json(message, 256)

    # When truncating UTF8 chars, payload size may be less than 256
    assert byte_size(payload) <= 256
    assert Poison.decode!(payload)["aps"]["alert"] == "ありがとうありがとうありがとうありがとうありがとうありがとうありがとうありがとうありがとうありがとうありがとうありがとうありがとうありがとうあ…"
  end

  test "build_json if PN length is less than 256, it is not truncated", %{message: message} do
    string = "lorem ipsum"
    message = Map.put(message, :alert, string)
    payload = Payload.build_json(message, 256)

    assert byte_size(payload) == @payload_min_size + byte_size(string)
    refute payload =~ "…"
  end

  test "build_json ellipsis absent when message size is exactly 256 bytes", %{message: message} do
    string = String.duplicate("a", 256 - @payload_min_size)
    message = Map.put(message, :alert, string)
    payload = Payload.build_json(message, 256)

    assert byte_size(payload) == @payload_min_size + byte_size(string)
    refute payload =~ "…"
  end

  test "build_json payload can be built for any characters", %{message: message} do
    string = "test123 тест テスト !@#$%"
    message = Map.put(message, :alert, string)
    payload = Payload.build_json(message, 256)

    assert byte_size(payload) == @payload_min_size + byte_size(string)
    refute payload =~ "…"
  end

  test "build_json adds sounds if present", %{message: message} do
    message = Map.put(message, :sound, "my sound")
    assert json_payload(message)["aps"]["sound"] == "my sound"
  end

  test "build_json adds category if present", %{message: message} do
    message = Map.put(message, :category, "my category")
    assert json_payload(message)["aps"]["category"] == "my category"
  end

  test "build_json adds badge if present", %{message: message} do
    message = Map.put(message, :badge, "my badge")
    assert json_payload(message)["aps"]["badge"] == "my badge"
  end

  test "build_json adds content_available if present", %{message: message} do
    message = Map.put(message, :'content_available', "my content_available")
    assert json_payload(message)["aps"]["content-available"] == "my content_available"
  end

  test "build_json adds mutable_content if present", %{message: message} do
    message = Map.put(message, :mutable_content, 1)
    assert json_payload(message)["aps"]["mutable-content"] == 1
  end

  test "build_json adds extra if present", %{message: message} do
    message = Map.put(message, :extra, %{customkey: "my extra"})
    assert json_payload(message)["customkey"] == "my extra"
  end

  test "build_json adds alert as binary", %{message: message} do
    message = Map.put(message, :alert, "just a string")
    assert json_payload(message)["aps"]["alert"] == "just a string"
  end

  test "build_json adds alert as notification struct", %{message: message} do
    alert = %APNS.Message.Loc{title: "My loc title"}
    message = Map.put(message, :alert, alert)
    assert json_payload(message)["aps"]["alert"]["title"] == "My loc title"
  end

  test "build_json always adds required notification components when given struct", %{message: message} do
    alert = %APNS.Message.Loc{}
    message = Map.put(message, :alert, alert)
    assert json_payload(message)["aps"]["alert"] == %{"body" => "", "loc-args" => [], "loc-key" => "", "title" => ""}
  end

  test "build_json optinally adds tite_loc_key given struct", %{message: message} do
    alert = %APNS.Message.Loc{title_loc_key: "my title loc key"}
    message = Map.put(message, :alert, alert)
    assert json_payload(message)["aps"]["alert"]["title-loc-key"] == "my title loc key"
  end

  test "build_json optinally adds title-loc-args given struct", %{message: message} do
    alert = %APNS.Message.Loc{title_loc_args: "my title loc args"}
    message = Map.put(message, :alert, alert)
    assert json_payload(message)["aps"]["alert"]["title-loc-args"] == "my title loc args"
  end

  test "build_json optinally adds action-loc-key given struct", %{message: message} do
    alert = %APNS.Message.Loc{action_loc_key: "my action loc key"}
    message = Map.put(message, :alert, alert)
    assert json_payload(message)["aps"]["alert"]["action-loc-key"] == "my action loc key"
  end

  test "build_json optinally adds launch-image given struct", %{message: message} do
    alert = %APNS.Message.Loc{launch_image: "my launch image"}
    message = Map.put(message, :alert, alert)
    assert json_payload(message)["aps"]["alert"]["launch-image"] == "my launch image"
  end

  defp json_payload(message) do
    Payload.build_json(message, 256) |> Poison.decode!()
  end
end
