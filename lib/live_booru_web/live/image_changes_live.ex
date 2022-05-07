defmodule LiveBooruWeb.ImageChangesLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.{Repo, ImageChange, Tag}

  import Ecto.Query, only: [from: 2, limit: 2, offset: 2]

  @limit 40

  def render(assigns) do
    LiveBooruWeb.PageView.render("image_changes.html", assigns)
  end

  def mount(params, _session, socket) do
    offset =
      case Integer.parse(Map.get(params, "offset", "")) do
        {n, _} -> n
        _ -> 0
      end

    socket =
      socket
      |> assign(:image_id, Map.get(params, "image_id", ""))
      |> assign(:user_id, Map.get(params, "user_id", ""))
      |> assign(:offset, offset)

    {changes, search_metadata} = get_changes(socket)

    socket =
      socket
      |> assign(:changes, changes)
      |> assign(:search_metadata, search_metadata)

    {:ok, socket}
  end

  def handle_params(params, session, socket) do
    {:ok, socket} = mount(params, session, socket)
    {:noreply, socket}
  end

  def handle_event("search", %{"image_id" => image_id, "user_id" => user_id}, socket) do
    {:noreply,
     push_patch(socket,
       to: Routes.live_path(socket, __MODULE__, image_id: image_id, user_id: user_id)
     )}
  end

  def get_changes(%{assigns: %{offset: offset_n}} = socket) do
    query = from(c in ImageChange, order_by: [desc: c.inserted_at])

    query =
      case Integer.parse(socket.assigns.image_id) do
        {image_id, _} -> from(q in query, where: q.image_id == ^image_id)
        _ -> query
      end

    query =
      case Integer.parse(socket.assigns.user_id) do
        {user_id, _} -> from(q in query, where: q.user_id == ^user_id)
        _ -> query
      end

    tags =
      Repo.all(from(t in Tag, select: {t.id, t.name}))
      |> Map.new()

    results =
      offset(query, ^offset_n)
      |> limit(@limit)
      |> Repo.all()
      |> Repo.preload([:user])
      |> Enum.map(fn change ->
        changes =
          Enum.map(change.tags_added, &{:added, Map.get(tags, &1)})
          |> Kernel.++(Enum.map(change.tags_removed, &{:removed, Map.get(tags, &1)}))
          |> Enum.sort_by(&elem(&1, 1))

        %{
          inserted_at: change.inserted_at,
          user: change.user,
          source_prev: change.source_prev,
          source: change.source,
          image_id: change.image_id,
          tags: Enum.map(change.tags, &Map.get(tags, &1)) |> Enum.sort(),
          changes: changes
        }
      end)

    count = Repo.aggregate(query, :count)

    {results, %{count: count, pages: max(ceil(count / @limit), 1), limit: @limit}}
  end
end
