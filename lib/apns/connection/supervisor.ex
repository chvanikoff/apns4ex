defmodule APNS.Connection.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link __MODULE__, [], [name: __MODULE__]
  end

  def start type do
    Supervisor.start_child __MODULE__, [type]
  end

  def init _args do
    children = [
      worker(APNS.Connection.Worker, [], restart: :permanent)
    ]
    opts = [strategy: :simple_one_for_one]
    supervise children, opts
  end
end