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

  def handle_info(%{event: "image_score", payload: {image_id, score}}, socket) do
    send_update(LiveBooruWeb.ImageDetailsComponent, id: "image_#{image_id}", score: score)
    {:noreply, socket}
  end

  def handle_info(%{event: "image", payload: image}, socket) do
    send_update(LiveBooruWeb.ImageDetailsComponent, id: "image_#{image.id}", image: image)
    {:noreply, socket}
  end

  def handle_info(%{event: "comment", payload: comment}, socket) do
    send_update(LiveBooruWeb.CommentComponent, id: "comment_#{comment.id}", comment: comment)
    {:noreply, socket}
  end

  def handle_info(%{event: "comments"}, socket) do
    {:noreply, assign(socket, comments: get_comments())}
  end

  def handle_event("comment_reply", %{"value" => comment_id}, socket) do
    case Repo.get(Comment, comment_id) do
      nil ->
        {:noreply, socket}

      %{image_id: image_id} ->
        socket =
          push_redirect(socket, to: Routes.live_path(socket, LiveBooruWeb.ImageLive, image_id))

        {:noreply, socket}
    end
  end

  def get_comments() do
    query =
      from c in Comment,
        order_by: [desc: c.inserted_at]

    Repo.all(query)
    |> Repo.preload([:user, [votes: :user], [image: [:user, :votes, :tags]]])
    |> Enum.chunk_by(& &1.image_id)
  end

  def update_comment(comment) do
    LiveBooruWeb.Endpoint.broadcast(@topic, "comment", comment)
  end

  def update_image(image) do
    LiveBooruWeb.Endpoint.broadcast(@topic, "image", image)
  end

  def update_image_score(%{id: image_id}, score) do
    LiveBooruWeb.Endpoint.broadcast(@topic, "image_score", {image_id, score})
  end

  def update() do
    LiveBooruWeb.Endpoint.broadcast(@topic, "comments", nil)
  end
end
