defmodule LiveBooruWeb.QueueLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.{Repo, EncodeJob, Encoder}

  def render(assigns) do
    LiveBooruWeb.PageView.render("queue.html", assigns)
  end

  def mount(_params, _session, socket) do
    %{working: working} = Encoder.get()

    working = Enum.map(working, & &1.id)

    queue =
      Repo.all(EncodeJob)
      |> Repo.preload(:user)
      |> Enum.map(&{&1, &1.id in working})

    socket =
      socket
      |> assign(:queue, queue)

    {:ok, socket}
  end

  def handle_params(_params, _session, socket) do
    {:noreply, socket}
  end
end
