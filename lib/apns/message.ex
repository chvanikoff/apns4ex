defmodule APNS.Message do
  defstruct [
    id: nil,
    expiry: 86400000,
    token: "",
    content_available: nil,
    alert: "",
    badge: nil,
    sound: "default",
    priority: 10,
    extra: [],
    support_old_ios: nil
  ]

  def new do
    {_, _, ms} = :os.timestamp
    s = :calendar.datetime_to_gregorian_seconds :calendar.universal_time
    f = rem s, 65536
    l = rem ms, 65536
    new <<f :: 8-unsigned-integer-unit(2), l :: 8-unsigned-integer-unit(2)>>
  end
  def new(id), do: %__MODULE__{id: id}

  defmodule Loc do
    defstruct [
      title: "",
      body: "",
      title_loc_key: nil,
      title_loc_args: nil,
      action_loc_key: nil,
      loc_key: "",
      loc_args: [],
      launch_image: nil
    ]
  end
end