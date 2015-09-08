defmodule APNS do
  use Application

  def start(env) when env in [:dev, :prod] do
    APNS.Connection.Supervisor.start(env)
  end

  def stop(pid) do
    Supervisor.terminate_child(APNS.Connection.Supervisor, pid)
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
  end

  defmodule Feedback do
    defstruct [
      time: nil,
      token: nil
    ]
  end
end
