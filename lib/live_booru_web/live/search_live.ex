defmodule LiveBooruWeb.SearchLive do
  use LiveBooruWeb, :live_component
  # use Phoenix.LiveView,
  #  container: {:div, class: __MODULE__ |> to_string() |> String.split(".") |> Enum.at(-1)}

  # import Phoenix.LiveView.Helpers
  # alias LiveBooruWeb.Router.Helpers, as: Routes

  def render(assigns) do
    LiveBooruWeb.PageView.render("search.html", assigns)
  end

  def mount(_, _, socket) do
    # socket = assign(socket, :q, "")
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
