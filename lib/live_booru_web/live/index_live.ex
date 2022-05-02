defmodule LiveBooruWeb.IndexLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.{Repo, Image}

  import Ecto.Query, only: [from: 2]

  def render(assigns) do
    LiveBooruWeb.PageView.render("index.html", assigns)
  end

  def tags(images) do
    images
    |> Enum.map(& &1.tags)
    |> List.flatten()
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(50)
    |> Enum.map(&elem(&1, 0))
    |> Repo.count_tags()
    |> Enum.sort_by(&elem(&1, 0).name, :asc)
  end

  def mount(%{"q" => ""}, _session, socket) do
    query = from i in Image, order_by: [desc: i.inserted_at]

    images =
      Repo.all(query)
      |> Repo.preload([:tags])

    socket =
      socket
      |> assign(:images, images)
      |> assign(:tags, tags(images))
      |> assign(:search, "")

    {:ok, socket}
  end

  def mount(%{"q" => q}, _session, socket) do
    images =
      Repo.search(q)
      |> Repo.preload([:tags])

    socket =
      socket
      |> assign(:images, images)
      |> assign(:tags, tags(images))
      |> assign(:search, q)

    {:ok, socket}
  end

  def mount(_params, session, socket) do
    mount(%{"q" => ""}, session, socket)
  end

  def handle_params(params, session, socket) do
    {:ok, socket} = mount(params, session, socket)
    {:noreply, socket}
  end
end
