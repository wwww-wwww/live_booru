defmodule LiveBooruWeb.ImageLive do
  use LiveBooruWeb, :live_view

  alias LiveBooruWeb.Endpoint
  alias LiveBooru.{Repo, Comment, Image, ImageVote}

  def render(assigns) do
    LiveBooruWeb.PageView.render("image.html", assigns)
  end

  def mount(%{"id" => id}, _session, socket) do
    Repo.get(Image, id)
    |> Repo.preload([[collections: :images], :tags, :user, :votes, [comments: [:user, :votes]]])
    |> case do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Image not found")
         |> push_redirect(to: "/")}

      image ->
        topic = "image:#{image.id}"
        if connected?(socket), do: LiveBooruWeb.Endpoint.subscribe(topic)

        tags =
          image.tags
          |> Repo.count_tags()
          |> Enum.sort_by(&elem(&1, 0).name)

        self_vote =
          case socket.assigns.current_user do
            nil ->
              nil

            user ->
              Repo.get_by(ImageVote, user_id: user.id, image_id: image.id)
              |> case do
                nil -> nil
                vote -> vote.upvote
              end
          end

        comments =
          Enum.map(image.comments, &{&1.id, &1})
          |> Map.new()

        source =
          URI.parse(image.source)
          |> case do
            %URI{host: nil} -> image.source
            _ -> live_redirect(image.source, to: image.source)
          end

        favorite = Repo.get_favorite(socket.assigns.current_user, image)

        favorites = Repo.count_favorites(image)

        socket =
          socket
          |> assign(:topic, topic)
          |> assign(:image, image)
          |> assign(:source, source)
          |> assign(:tags, tags)
          |> assign(:self_vote, self_vote)
          |> assign(:current_comment, "")
          |> assign(:editing, true)
          |> assign(:preview, nil)
          |> assign(:comments, comments)
          |> assign(:favorite, favorite)
          |> assign(:favorites, favorites)

        {:ok, socket}
    end
  end

  def handle_params(%{"id" => id}, session, socket) do
    {:ok, socket} = mount(%{"id" => id}, session, socket)
    {:noreply, socket}
  end

  def handle_info(%{event: "score", payload: score}, socket) do
    {:noreply, assign(socket, score: score)}
  end

  def handle_info(%{event: "favorites", payload: favorites}, socket) do
    {:noreply, assign(socket, favorites: favorites)}
  end

  def handle_info(%{event: "comment", payload: comment}, socket) do
    {:noreply, assign(socket, :comments, Map.put(socket.assigns.comments, comment.id, comment))}
  end

  def handle_info(%{event: "comment_delete", payload: comment}, socket) do
    {:noreply, assign(socket, :comments, Map.delete(socket.assigns.comments, comment))}
  end

  def handle_info(%{event: "comment_update", payload: comment}, socket) do
    send_update(LiveBooruWeb.CommentComponent, id: "comment_#{comment.id}", comment: comment)
    {:noreply, assign(socket, :comments, Map.put(socket.assigns.comments, comment.id, comment))}
  end

  def handle_event("vote_up", _, socket) do
    ImageVote.add(socket.assigns.current_user, socket.assigns.image, true)
    |> case do
      {:ok, up} ->
        Endpoint.broadcast(
          "image:#{socket.assigns.image.id}",
          "score",
          ImageVote.get_score(socket.assigns.image)
        )

        {:noreply, assign(socket, :self_vote, up)}

      {:error, cs} ->
        {:noreply, put_flash(socket, :error, inspect(cs))}
    end
  end

  def handle_event("vote_down", _, socket) do
    ImageVote.add(socket.assigns.current_user, socket.assigns.image, false)
    |> case do
      {:ok, up} ->
        Endpoint.broadcast(
          "image:#{socket.assigns.image.id}",
          "score",
          ImageVote.get_score(socket.assigns.image)
        )

        {:noreply, assign(socket, :self_vote, up)}

      {:error, cs} ->
        {:noreply, put_flash(socket, :error, inspect(cs))}
    end
  end

  def handle_event("comment_reply", %{"value" => comment}, socket) do
    socket =
      assign(socket, :current_comment, socket.assigns.current_comment <> "%Comment{#{comment}}")

    {:noreply, socket}
  end

  def handle_event("comment_edit", _, socket) do
    {:noreply, assign(socket, :editing, true)}
  end

  def handle_event("comment_preview", _, socket) do
    socket =
      socket
      |> assign(:editing, false)
      |> assign(
        :preview,
        LiveBooruWeb.PageView.format_description(socket, socket.assigns.current_comment)
      )

    {:noreply, socket}
  end

  def handle_event("comment_save", %{"comment" => comment}, socket) do
    {:noreply, assign(socket, :current_comment, comment)}
  end

  def handle_event("comment_create", _, socket) do
    case String.trim(socket.assigns.current_comment) do
      "" ->
        {:noreply, put_flash(socket, :comment_error, "Comment can't be empty.")}

      comment ->
        Comment.new(comment, socket.assigns.current_user, socket.assigns.image)
        |> Repo.insert()
        |> case do
          {:ok, comment} ->
            Endpoint.broadcast(
              "image:#{socket.assigns.image.id}",
              "comment",
              Repo.preload(comment, [:user, [votes: :user]])
            )

            socket =
              socket
              |> assign(:current_comment, "")
              |> assign(:preview, nil)
              |> assign(:editing, true)

            {:noreply, socket}

          {:error, cs} ->
            {:noreply, put_flash(socket, :comment_error, inspect(cs))}
        end
    end
  end

  def handle_event("favorites_add", _, %{assigns: %{current_user: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("favorites_add", _, %{assigns: %{current_user: current_user}} = socket) do
    socket =
      case Repo.get_favorites(current_user) do
        nil ->
          Repo.create_favorites(current_user)

        favorites ->
          favorites
      end
      |> case do
        {:error, _err} ->
          socket

        collection ->
          Repo.add_favorites(collection, socket.assigns.image)
          |> case do
            {:error, _err} ->
              socket

            {:ok, favorite} ->
              Endpoint.broadcast(
                "image:#{socket.assigns.image.id}",
                "favorites",
                Repo.count_favorites(socket.assigns.image)
              )

              assign(socket, :favorite, favorite)
          end
      end

    {:noreply, socket}
  end

  def handle_event("favorites_remove", _, socket) do
    if socket.assigns.favorite != nil do
      Repo.delete(socket.assigns.favorite)

      Endpoint.broadcast(
        "image:#{socket.assigns.image.id}",
        "favorites",
        Repo.count_favorites(socket.assigns.image)
      )
    end

    {:noreply, assign(socket, :favorite, nil)}
  end
end

defmodule LiveBooruWeb.ImageMoreLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.{Repo, Image}

  def render(assigns) do
    LiveBooruWeb.PageView.render("image_more.html", assigns)
  end

  def mount(%{"id" => id}, _session, socket) do
    Repo.get(Image, id)
    |> Repo.preload([[uploads: :user], [collections: :images], :tags, :user, :votes, :comments])
    |> case do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Image not found")
         |> push_redirect(to: "/")}

      image ->
        score = image.votes |> Enum.reduce(0, &if(&1.upvote, do: &2 + 1, else: &2 - 1))

        socket =
          socket
          |> assign(:image, image)
          |> assign(:score, score)

        {:ok, socket}
    end
  end

  def handle_params(%{"id" => id}, session, socket) do
    {:ok, socket} = mount(%{"id" => id}, session, socket)
    {:noreply, socket}
  end
end

defmodule LiveBooruWeb.ImageChangesLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.{Repo, Image, Tag}

  def render(assigns) do
    LiveBooruWeb.PageView.render("image_changes.html", assigns)
  end

  def mount(%{"id" => id}, _session, socket) do
    Repo.get(Image, id)
    |> Repo.preload([[changes: :user]])
    |> case do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Image not found")
         |> push_redirect(to: "/")}

      image ->
        changes =
          image.changes
          |> Enum.map(fn change ->
            %{
              user: change.user,
              inserted_at: change.inserted_at,
              tags:
                Enum.map(change.tags, fn tag ->
                  case Repo.get(Tag, tag) do
                    nil -> tag
                    tag -> tag.name
                  end
                end),
              source: change.source
            }
          end)

        socket =
          socket
          |> assign(:changes, changes)
          |> assign(:image, image)

        {:ok, socket}
    end
  end

  def handle_params(%{"id" => id}, session, socket) do
    {:ok, socket} = mount(%{"id" => id}, session, socket)
    {:noreply, socket}
  end
end
