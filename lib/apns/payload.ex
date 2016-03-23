defmodule APNS.Payload do
  defmodule Aps do
    defstruct [:sound, :category, :badge, :content_available, :alert]
  end

  import APNS.Utils.Map, only: [compact: 1, rename_key: 3]

  def build_json(%APNS.Message{} = message, limit) do
    payload =
      aps(%{}, message)
      |> alert(message.alert)
      |> extra(message.extra)

    json = Poison.encode!(payload)

    length_diff = byte_size(json) - limit
    length_alert = case payload.aps.alert do
      %{body: body} -> byte_size(body)
      str when is_binary(str) -> byte_size(str)
    end

    cond do
      length_diff <= 0 -> json
      length_diff >= length_alert -> {:error, :payload_size_exceeded}
      true ->
        payload = put_in(payload[:aps][:alert], truncate(payload.aps.alert, length_alert - length_diff))
        Poison.encode!(payload)
    end
  end

  defp aps(payload, message) do
    merged =
      struct(%APNS.Payload.Aps{}, Map.from_struct(message))
      |> Map.from_struct()
      |> rename_key(:content_available, :'content-available')
      |> compact()

    Map.put(payload, :aps, merged)
  end

  defp extra(payload, []), do: payload
  defp extra(payload, extra), do: Map.merge(payload, extra)

  defp alert(payload, %APNS.Message.Loc{} = map), do: put_in(payload, [:aps, :alert], format_loc(map))
  defp alert(payload, _), do: payload

  defp truncate(%{body: string} = alert, size) do
    %{alert | body: truncate(string, size)}
  end

  defp truncate(string, size) when is_binary(string) do
    string2 = string <> "…"

    if byte_size(string2) <= size do
      string2
    else
      string = String.slice(string, 0, String.length(string) - 1)
      truncate(string, size)
    end
  end

  defp format_loc(%APNS.Message.Loc{
    title: title, body: body, title_loc_key: title_loc_key,
    title_loc_args: title_loc_args, action_loc_key: action_loc_key,
    loc_key: loc_key, loc_args: loc_args, launch_image: launch_image}) do

    required = %{
      "title": title,
      "body": body,
      "loc-key": loc_key,
      "loc-args": loc_args
    }

    optional = %{
      "title-loc-key": title_loc_key,
      "title-loc-args": title_loc_args,
      "action-loc-key": action_loc_key,
      "launch-image": launch_image
    } |> compact()

    Map.merge(required, optional)
  end
end
