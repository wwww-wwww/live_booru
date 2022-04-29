defmodule LiveBooruWeb.TagListLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.{Repo, Tag}

  def render(assigns) do
    LiveBooruWeb.PageView.render("taglist.html", assigns)
  end

  def mount(_, _session, socket) do
    socket = assign(socket, tags: Repo.all(Tag) |> Enum.sort_by(& &1.id, :desc))
    {:ok, socket}
  end

  def handle_params(_, _, socket) do
    {:noreply, socket}
  end
end
