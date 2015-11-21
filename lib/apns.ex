defmodule APNS do
  use Application

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
        worker_module: APNS.Worker,
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
end
