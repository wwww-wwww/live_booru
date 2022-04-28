defmodule LiveBooruWeb.TagListLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.{Repo, Tag}

  @re_dimensions ~r/^dimensions: *([0-9]+)?x([0-9]+)/

  def render(assigns) do
    LiveBooruWeb.PageView.render("taglist.html", assigns)
  end

  def mount(_, session, socket) do
    socket = assign(socket, tags: Repo.all(Tag) |> Enum.sort_by(& &1.id, :desc))
    {:ok, socket}
  end

  def handle_params(_, _, socket) do
    {:noreply, socket}
  end
end
