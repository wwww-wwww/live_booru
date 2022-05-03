defmodule LiveBooruWeb.AllTagChangesLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.{Repo, TagChange}

  import Ecto.Query, only: [from: 2]

  @topic "tags"

  def render(assigns) do
    LiveBooruWeb.PageView.render("all_tag_changes.html", assigns)
  end

  def mount(_params, _session, socket) do
    if connected?(socket), do: LiveBooruWeb.Endpoint.subscribe(@topic)

    {:ok, assign(socket, :changes, get_changes())}
  end

  def handle_params(_params, _session, socket) do
    {:noreply, socket}
  end

  def handle_info(%{event: "changes", payload: changes}, socket) do
    {:noreply, assign(socket, changes: changes)}
  end

  def get_changes() do
    query =
      from c in TagChange,
        order_by: [desc: c.inserted_at]

    Repo.all(query)
    |> Repo.preload([:user, :tag])
  end

  def update() do
    LiveBooruWeb.Endpoint.broadcast(@topic, "changes", get_changes())
  end
end
