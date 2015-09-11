defmodule APNS do
  use Application
  defmodule Message do
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

  def start(env) when env in [:dev, :prod] do
    APNS.Connection.Supervisor.start(env)
  end

  def stop(pid) do
    Supervisor.terminate_child(APNS.Connection.Supervisor, pid)
  end

  def push(conn, token, alert) do
    msg = APNS.Message.new
    |> Map.put(:token, token)
    |> Map.put(:alert, alert)
    push(conn, msg)
  end

  def push(conn, %APNS.Message{} = msg) do
    APNS.Connection.Worker.push(conn, msg)
  end
  
  
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Define workers and child supervisors to be supervised
      # worker(APNS.Worker, [arg1, arg2, arg3]),
      supervisor(APNS.Connection.Supervisor, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: APNS.Supervisor]
    Supervisor.start_link(children, opts)
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
