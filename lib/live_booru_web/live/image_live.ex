defmodule LiveBooruWeb.ImageLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.{Comment, Repo, Image}

  def render(assigns) do
    LiveBooruWeb.PageView.render("image.html", assigns)
  end

  def mount(%{"id" => id}, _session, socket) do
    Repo.get(Image, id)
    |> Repo.preload([[collections: :images], :tags, :user, :votes, [comments: :user]])
    |> case do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Image not found")
         |> push_redirect(to: "/")}

      image ->
        topic = "image:#{image.id}"
        if connected?(socket), do: LiveBooruWeb.Endpoint.subscribe(topic)

        score = image.votes |> Enum.reduce(0, &if(&1.upvote, do: &2 + 1, else: &2 - 1))

        tags =
          image.tags
          |> Repo.count_tags()
          |> Enum.sort_by(&elem(&1, 0).name)

        socket =
          socket
          |> assign(:topic, topic)
          |> assign(:image, image)
          |> assign(:tags, tags)
          |> assign(:score, score)
          |> assign(:current_comment, "")
          |> assign(:editing, true)
          |> assign(:preview, nil)
          |> assign(:comments, image.comments)

        {:ok, socket}
    end
  end

  def handle_params(%{"id" => id}, session, socket) do
    {:ok, socket} = mount(%{"id" => id}, session, socket)
    {:noreply, socket}
  end

  def handle_info(%{event: "comment", payload: comment}, socket) do
    {:noreply,
     assign(socket, :comments, Enum.uniq_by(socket.assigns.comments ++ [comment], & &1.id))}
  end

  def handle_info(%{event: "comment_delete", payload: comment}, socket) do
    {:noreply,
     assign(socket, :comments, Enum.filter(socket.assigns.comments, &(&1.id != comment)))}
  end

  def handle_event("comment_reply", %{"value" => comment}, socket) do
    socket =
      socket
      |> assign(:current_comment, socket.assigns.current_comment <> "%Comment{#{comment}}")

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
        {:noreply, put_flash(socket, :error, "Comment can't be empty.")}

      comment ->
        Comment.new(comment, socket.assigns.current_user, socket.assigns.image)
        |> Repo.insert()
        |> case do
          {:ok, comment} ->
            LiveBooruWeb.Endpoint.broadcast(
              "image:#{socket.assigns.image.id}",
              "comment",
              comment
            )

            socket =
              socket
              |> assign(:current_comment, "")
              |> assign(:preview, nil)
              |> assign(:editing, true)

            {:noreply, socket}

          {:error, cs} ->
            {:noreply, put_flash(socket, :error, inspect(cs))}
        end
    end
  end

  def handle_event("comment_delete", %{"value" => comment}, socket) do
    Repo.get(Comment, comment)
    |> case do
      nil ->
        {:noreply, socket}

      comment ->
        if comment.user_id == socket.assigns.current_user.id do
          Repo.delete(comment)

          LiveBooruWeb.Endpoint.broadcast(
            "image:#{socket.assigns.image.id}",
            "comment_delete",
            comment.id
          )
        end

        {:noreply, socket}
    end
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
