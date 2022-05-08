defmodule LiveBooruWeb.TagListLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.{Repo, Tag}

  def render(assigns) do
    LiveBooruWeb.PageView.render("taglist.html", assigns)
  end

  def mount(_, _session, socket) do
    tags =
      Repo.all(Tag)
      |> Repo.preload([:tag, :parent])
      |> Repo.count_tags()
      |> Enum.sort_by(&elem(&1, 0).id, :desc)

    socket = assign(socket, tags: tags)
    {:ok, socket}
  end

  def handle_params(_, _, socket) do
    {:noreply, socket}
  end

  def handle_event("tag_create", %{"name" => ""}, socket), do: {:noreply, socket}

  def handle_event("tag_create", %{"name" => name}, socket) do
    if !is_nil(socket.assigns.current_user) and socket.assigns.current_user.level >= 100 do
      String.trim(name)
      |> case do
        "" ->
          {:noreply, socket}

        name ->
          case Repo.get_tag(name) do
            nil ->
              Tag.new(name) |> Repo.insert()

              tags =
                Repo.all(Tag)
                |> Repo.preload([:tag, :parent])
                |> Repo.count_tags()
                |> Enum.sort_by(&elem(&1, 0).id, :desc)

              {:noreply, assign(socket, tags: tags)}

            _ ->
              {:noreply, socket}
          end
      end
    else
      {:noreply, socket}
    end
  end
end
