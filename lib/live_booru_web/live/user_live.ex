defmodule LiveBooruWeb.UserLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.Accounts.User

  alias LiveBooru.{
    Repo,
    Image,
    Comment,
    ImageChange,
    TagChange,
    Collection,
    ImagesCollections,
    ImageVote,
    CommentVote
  }

  import Ecto.Query, only: [from: 2]

  def render(assigns) do
    LiveBooruWeb.UserView.render("profile.html", assigns)
  end

  def mount(%{"id" => id}, _, socket) do
    Repo.get(User, id)
    |> Repo.preload(collections: [image_collection: :image])
    |> case do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "User not found.")
         |> push_redirect(to: "/")}

      %{id: user_id} = user ->
        n_images =
          from(i in Image, where: i.user_id == ^user_id)
          |> Repo.aggregate(:count)

        n_comments =
          from(c in Comment, where: c.user_id == ^user_id)
          |> Repo.aggregate(:count)

        n_image_changes =
          from(c in ImageChange, where: c.user_id == ^user_id)
          |> Repo.aggregate(:count)

        n_tag_changes =
          from(c in TagChange, where: c.user_id == ^user_id)
          |> Repo.aggregate(:count)

        n_favorites =
          from(ic in ImagesCollections,
            join: c in Collection,
            on: c.id == ic.collection_id,
            where: c.user_id == ^user_id
          )
          |> Repo.aggregate(:count)

        post_score =
          from(v in ImageVote,
            join: i in Image,
            on: i.id == v.image_id,
            where: i.user_id == ^user_id,
            select: sum(fragment("case when ? then 1 else -1 end", v.upvote))
          )
          |> Repo.one()
          |> Kernel.||(0)

        comment_score =
          from(v in CommentVote,
            join: i in Comment,
            on: i.id == v.comment_id,
            where: i.user_id == ^user_id,
            select: sum(fragment("case when ? then 1 else -1 end", v.upvote))
          )
          |> Repo.one()
          |> Kernel.||(0)

        socket =
          socket
          |> assign(user: user)
          |> assign(n_images: n_images)
          |> assign(n_comments: n_comments)
          |> assign(n_image_changes: n_image_changes)
          |> assign(n_tag_changes: n_tag_changes)
          |> assign(n_favorites: n_favorites)
          |> assign(post_score: post_score)
          |> assign(comment_score: comment_score)
          |> assign(
            same_user:
              !is_nil(socket.assigns.current_user) and socket.assigns.current_user.id == user.id
          )

        socket =
          if socket.assigns.same_user do
            assign(socket, changeset: Ecto.Changeset.change(user))
          else
            socket
          end

        {:ok, socket}
    end
  end

  def handle_info(params, session, socket) do
    {:ok, socket} = mount(params, session, socket)
    {:noreply, socket}
  end

  def handle_event("delete_collection", _, %{assigns: %{current_user: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("delete_collection", %{"value" => id}, socket) do
    if socket.assigns.same_user do
      Repo.get(Collection, id)
      |> Repo.delete()
    end

    {:noreply,
     assign(
       socket,
       :user,
       Repo.get(User, socket.assigns.user.id) |> Repo.preload(collections: :images)
     )}
  end

  def handle_event("settings", %{"user" => attrs}, socket) do
    if socket.assigns.same_user do
      cs = Ecto.Changeset.cast(socket.assigns.changeset, attrs, [:index_default_safe, :theme])

      case Repo.update(cs) do
        {:ok, user} ->
          if Map.has_key?(cs.changes, :theme) do
            {:noreply, redirect(socket, to: Routes.live_path(socket, __MODULE__, user.id))}
          else
            {:noreply, assign(socket, changeset: Ecto.Changeset.change(user))}
          end

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end
end

defmodule LiveBooruWeb.SignInLive do
  use LiveBooruWeb, :live_view

  def render(assigns) do
    LiveBooruWeb.UserView.render("sign_in.html", assigns)
  end

  def mount(_, _, socket) do
    {:ok, socket}
  end
end

defmodule LiveBooruWeb.SignUpLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.Accounts
  alias LiveBooru.Accounts.User

  def render(assigns) do
    LiveBooruWeb.UserView.render("sign_up.html", assigns)
  end

  def mount(_, _, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket = assign(socket, changeset: changeset)
    {:ok, socket}
  end
end
