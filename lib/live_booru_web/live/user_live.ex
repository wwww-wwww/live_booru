defmodule LiveBooruWeb.UserLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.Accounts.User
  alias LiveBooru.{Repo, Image, Comment, ImageChange, TagChange, Collection, ImagesCollections}

  import Ecto.Query, only: [from: 2]

  def render(assigns) do
    LiveBooruWeb.UserView.render("profile.html", assigns)
  end

  def mount(%{"id" => id}, _, socket) do
    Repo.get(User, id)
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

        socket =
          socket
          |> assign(user: user)
          |> assign(n_images: n_images)
          |> assign(n_comments: n_comments)
          |> assign(n_image_changes: n_image_changes)
          |> assign(n_tag_changes: n_tag_changes)
          |> assign(n_favorites: n_favorites)

        {:ok, socket}
    end
  end

  def handle_info(params, session, socket) do
    {:ok, socket} = mount(params, session, socket)
    {:noreply, socket}
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
