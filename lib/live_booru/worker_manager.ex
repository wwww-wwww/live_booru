defmodule LiveBooru.WorkerManager do
  use GenServer

  alias LiveBooru.Repo

  defstruct workers: [], queue: nil, working: [], name: nil

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def init(opts) do
    {:ok,
     %__MODULE__{
       queue: opts[:queue],
       name: to_string(opts[:name]) |> String.split(".") |> Enum.take(-1)
     }}
  end

  def handle_call(:get, _from, state) do
    {:reply, state, state}
  end

  # always hot
  def handle_call({:pop, opts}, _from, state) do
    Repo.all(state.queue)
    |> Enum.filter(&(&1.id not in Enum.map(state.working, fn j -> j.id end)))
    |> Enum.sort_by(Keyword.get(opts, :sort_by, fn _ -> nil end), Keyword.get(opts, :order, :asc))
    |> Enum.at(0)
    |> case do
      nil ->
        {:reply, :empty, state}

      job ->
        job = Repo.preload(job, :user)

        working =
          if Keyword.get(opts, :track, true) do
            state.working ++ [job]
          else
            state.working
          end

        # Status.put(state.name, "#{:queue.len(queue)} items in queue, #{length(working)} working")
        {:reply, job, %{state | working: working}}
    end
  end

  def handle_call({:register, pid}, _from, state) do
    {:reply, :ok, %{state | workers: state.workers ++ [pid]}}
  end

  def handle_call({:finish, job}, _from, state) do
    working = state.working -- [job]
    Repo.delete(job)

    # Status.put(
    #  state.name,
    #  "#{:queue.len(state.queue)} items in queue, #{length(working)} working"
    # )

    {:reply, :ok, %{state | working: working}}
  end

  def handle_call({:reset, job}, _from, state) do
    working = state.working -- [job]

    # Status.put(
    #  state.name,
    #  "#{:queue.len(state.queue)} items in queue, #{length(working)} working"
    # )

    {:reply, :ok, %{state | working: working}}
  end

  def handle_cast(:notify, state) do
    Enum.each(state.workers, &GenServer.cast(&1, :loop))
    {:noreply, state}
  end

  def get(pid) do
    GenServer.call(pid, :get)
  end

  def pop(pid, opts \\ []) do
    GenServer.call(pid, {:pop, opts})
  end

  def notify(pid), do: GenServer.cast(pid, :notify)

  def finish(pid, job), do: GenServer.call(pid, {:finish, job})

  def reset(pid, job), do: GenServer.call(pid, {:reset, job})
end
