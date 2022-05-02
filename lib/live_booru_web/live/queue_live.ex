defmodule LiveBooruWeb.QueueLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.{Repo, EncodeJob, Encoder}

  @topic "queue"

  def render(assigns) do
    LiveBooruWeb.PageView.render("queue.html", assigns)
  end

  def mount(_params, _session, socket) do
    if connected?(socket), do: LiveBooruWeb.Endpoint.subscribe(@topic)

    {:ok, assign(socket, :queue, get_queue())}
  end

  def handle_params(_params, _session, socket) do
    {:noreply, socket}
  end

  def handle_info(%{event: "queue", payload: queue}, socket) do
    {:noreply, assign(socket, queue: queue)}
  end

  def get_queue() do
    %{working: working} = Encoder.get()

    working = Enum.map(working, & &1.id)

    Repo.all(EncodeJob)
    |> Repo.preload(:user)
    |> Enum.sort_by(& &1.id)
    |> Enum.map(&{&1, &1.id in working})
  end

  def update() do
    LiveBooruWeb.Endpoint.broadcast(@topic, "queue", get_queue())
  end
end
