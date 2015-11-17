defmodule APNS do
  use Application
  defmodule Message do
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
  end

  def push(pool, token, alert) do
    msg = APNS.Message.new
    |> Map.put(:token, token)
    |> Map.put(:alert, alert)
    push(pool, msg)
  end

  def push(pool, %APNS.Message{} = msg) do
    :poolboy.transaction(pool_name(pool), fn(pid) ->
      GenServer.call(pid, msg)
    end)
  end

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = Application.get_env(:apns, :pools)
    |> Enum.map(fn({name, conf}) ->
      pool_args = [
        name: {:local, pool_name(name)},
        worker_module: APNS.Connection.Worker,
        size: conf[:pool_size],
        max_overflow: conf[:pool_max_overflow],
        strategy: :fifo
      ]
      :poolboy.child_spec(pool_name(name), pool_args, name)
    end)
    
    opts = [strategy: :one_for_one, name: APNS.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def pool_name(name) do
    "APNS.Pool.#{to_string(name)}" |> String.to_atom
  end

  defmodule Error do
    defstruct [
      message_id: nil,
      status: nil,
      error: nil
    ]
    @statuses %{
      0 => "No errors encountered",
      1 => "Processing",
      2 => "Missing device token",
      3 => "Missing topic",
      4 => "Missing payload",
      5 => "Invalid token size",
      6 => "Invalid topic size",
      7 => "Invalid payload size",
      8 => "Invalid token",
      10 => "Shutdown",
      255 => "None (unknown)"
    }
    def new(msg_id, status) do
      %__MODULE__{message_id: msg_id, status: status, error: @statuses[status]}
    end
  end

  defmodule Feedback do
    defstruct [
      time: nil,
      token: nil
    ]
  end
end
