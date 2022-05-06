defmodule LiveBooruWeb.AllImageChangesLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.{Repo, ImageChange, Tag}

  import Ecto.Query, only: [from: 2]

  def render(assigns) do
    LiveBooruWeb.PageView.render("all_image_changes.html", assigns)
  end

  def mount(_params, _session, socket) do
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
      from c in ImageChange,
        order_by: [desc: c.inserted_at]

    tags =
      Repo.all(from(t in Tag, select: {t.id, t.name}))
      |> Map.new()

    Repo.all(query)
    |> Repo.preload([:user])
    |> Enum.map(fn change ->
      %{
        inserted_at: change.inserted_at,
        user: change.user,
        source_prev: change.source_prev,
        source: change.source,
        image_id: change.image_id,
        tags: Enum.map(change.tags, &Map.get(tags, &1)) |> Enum.sort(),
        added: Enum.map(change.tags_added || [], &Map.get(tags, &1)) |> Enum.sort(),
        removed: Enum.map(change.tags_removed || [], &Map.get(tags, &1)) |> Enum.sort()
      }
    end)
  end
end
