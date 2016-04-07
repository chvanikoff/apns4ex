defmodule APNS do
  use Application

  def push(pool, token, alert) do
    message =
      APNS.Message.new
      |> Map.put(:token, token)
      |> Map.put(:alert, alert)

    push(pool, message)
  end

  def push(pool, %APNS.Message{} = message) do
    :poolboy.transaction(pool_name(pool), fn(pid) ->
      APNS.MessageWorker.push(pid, message)
    end)
  end

  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: APNS.Supervisor]
    supervisor = Supervisor.start_link([], opts)

    pools = Application.get_env(:apns, :pools)
    pools |> Enum.map(fn({name, conf}) -> connect_pool(name, conf) end)

    supervisor
  end

  def connect_pool(name, conf) do
    pool_args = [
      name: {:local, pool_name(name)},
      worker_module: APNS.MessageWorker,
      size: conf[:pool_size],
      max_overflow: conf[:pool_max_overflow],
      strategy: :fifo
    ]
    conf = Keyword.put(conf, :pool, name)
    child_spec = :poolboy.child_spec(pool_name(name), pool_args, conf)

    Supervisor.start_child(APNS.Supervisor, child_spec)

    feedback_worker = Supervisor.Spec.worker(APNS.FeedbackWorker, [conf], id: worker_name(:feedback, name))
    Supervisor.start_child(APNS.Supervisor, feedback_worker)
  end

  defp pool_name(name) do
    String.to_atom("APNS.Pool.#{to_string(name)}")
  end

  defp worker_name(type, pool) do
    String.to_atom("#{type}_worker_#{pool_name(pool)}")
  end
end
