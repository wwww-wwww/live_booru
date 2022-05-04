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
end
