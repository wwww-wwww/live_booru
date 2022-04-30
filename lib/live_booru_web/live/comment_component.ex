defmodule LiveBooruWeb.CommentComponent do
  use LiveBooruWeb, :live_component

  alias LiveBooruWeb.Endpoint
  alias LiveBooru.{Repo, Comment, CommentVote}

  def render(assigns) do
    LiveBooruWeb.ComponentView.render("comment.html", assigns)
  end

  def update(assigns, socket) do
    socket = assign(socket, assigns)

    self_vote =
      if socket.assigns.current_user do
        Enum.filter(socket.assigns.comment.votes, &(&1.user_id == socket.assigns.current_user.id))
        |> case do
          [] -> nil
          [%{upvote: upvote}] -> upvote
        end
      else
        nil
      end

    socket =
      socket
      |> assign(:self_vote, self_vote)

    {:ok, socket}
  end

  def handle_event("vote_up", _, socket) do
    CommentVote.add(socket.assigns.current_user, socket.assigns.comment, true)
    |> case do
      {:ok, _} ->
        Endpoint.broadcast(
          "image:#{socket.assigns.comment.image_id}",
          "comment_update",
          Repo.get(Comment, socket.assigns.comment.id) |> Repo.preload([:user, votes: :user])
        )

        {:noreply, socket}

      {:error, cs} ->
        {:noreply, put_flash(socket, :error, inspect(cs))}
    end
  end

  def handle_event("vote_down", _, socket) do
    CommentVote.add(socket.assigns.current_user, socket.assigns.comment, false)
    |> case do
      {:ok, _} ->
        Endpoint.broadcast(
          "image:#{socket.assigns.comment.image_id}",
          "comment_update",
          Repo.get(Comment, socket.assigns.comment.id) |> Repo.preload([:user, votes: :user])
        )

        {:noreply, socket}

      {:error, cs} ->
        {:noreply, put_flash(socket, :error, inspect(cs))}
    end
  end

  def handle_event("delete", %{"value" => comment}, socket) do
    Repo.get(Comment, comment)
    |> case do
      nil ->
        {:noreply, socket}

      comment ->
        if comment.user_id == socket.assigns.current_user.id do
          Repo.delete(comment)

          Endpoint.broadcast(
            "image:#{socket.assigns.comment.image_id}",
            "comment_delete",
            comment.id
          )
        end

        {:noreply, socket}
    end
  end
end
