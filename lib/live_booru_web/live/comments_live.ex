defmodule LiveBooruWeb.CommentsLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.{Repo, Comment}

  import Ecto.Query, only: [from: 2]

  @topic "comments"

  def render(assigns) do
    LiveBooruWeb.PageView.render("comments.html", assigns)
  end

  def mount(_params, _session, socket) do
    if connected?(socket), do: LiveBooruWeb.Endpoint.subscribe(@topic)

    {:ok, assign(socket, :comments, get_comments())}
  end

  def handle_params(_params, _session, socket) do
    {:noreply, socket}
  end

  def handle_info(%{event: "comments"}, socket) do
    {:noreply, assign(socket, comments: get_comments())}
  end

  def get_comments() do
    query =
      from c in Comment,
        order_by: [desc: c.inserted_at]

    Repo.all(query)
    |> Repo.preload([:user, [votes: :user], [image: [:user, :votes, :tags]]])
    |> Enum.chunk_by(& &1.image_id)
  end

  def update() do
    LiveBooruWeb.Endpoint.broadcast(@topic, "comments", nil)
  end
end
