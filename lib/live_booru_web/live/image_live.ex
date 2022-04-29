defmodule LiveBooruWeb.ImageLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.{Repo, Image}

  def render(assigns) do
    LiveBooruWeb.PageView.render("image.html", assigns)
  end

  def mount(%{"id" => id}, _session, socket) do
    Repo.get(Image, id)
    |> Repo.preload([[collections: :images], :tags, :user, :votes, :comments])
    |> case do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Image not found")
         |> push_redirect(to: "/")}

      image ->
        score = image.votes |> Enum.reduce(0, &if(&1.upvote, do: &2 + 1, else: &2 - 1))

        tags =
          image.tags
          |> Repo.count_tags()
          |> Enum.sort_by(&elem(&1, 0).name)

        socket =
          socket
          |> assign(:image, image)
          |> assign(:tags, tags)
          |> assign(:score, score)

        {:ok, socket}
    end
  end

  def handle_params(%{"id" => id}, session, socket) do
    {:ok, socket} = mount(%{"id" => id}, session, socket)
    {:noreply, socket}
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
