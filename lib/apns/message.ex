defmodule APNS.Message do
  defstruct [
    id: nil,
    category: nil,
    expiry: 60,
    generated_at: nil,
    token: "",
    content_available: nil,
    alert: "",
    badge: nil,
    sound: "default",
    mutable_content: nil,
    priority: 10,
    extra: [],
    support_old_ios: nil,
    retry_count: 0
  ]

  def new do
    make_ref() |> :erlang.phash2() |> new()
  end

  def new(id) when is_number(id) do
    %__MODULE__{
      id: id,
      generated_at: :os.system_time(:seconds)
    }
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
