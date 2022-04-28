defmodule LiveBooruWeb.SearchLive do
  use LiveBooruWeb, :live_component

  alias LiveBooru.{Repo, EncodeJob, Encoder}

  def render(assigns) do
    LiveBooruWeb.PageView.render("search.html", assigns)
  end

  def mount(_, _, socket) do
    {:ok, socket}
  end

  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> put_flash(:search, query)
      |> push_redirect(to: Routes.live_path(socket, LiveBooruWeb.IndexLive, q: query))

    {:noreply, socket}
  end
end
