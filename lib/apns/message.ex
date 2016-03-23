defmodule APNS.Message do
  defstruct [
    id: nil,
    category: nil,
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
    make_ref() |> :erlang.phash2() |> new()
  end

  def new(id) do
    %__MODULE__{id: id}
  end

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
