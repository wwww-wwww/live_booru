defmodule LiveBooruWeb.IndexLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.{Repo}

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

  def mount(%{"q" => q, "offset" => offset}, _session, socket) do
    {offset, _} = Integer.parse(to_string(offset))
    {images, search_metadata} = Repo.search(q, offset: offset)

    images =
      images
      |> Repo.preload([:tags])

    socket =
      socket
      |> assign(:images, images)
      |> assign(:search_metadata, search_metadata)
      |> assign(:tags, tags(images))
      |> assign(:search, q)
      |> assign(:offset, offset)

    {:ok, socket}
  end

  def mount(%{"q" => q}, session, socket) do
    mount(%{"q" => q, "offset" => 0}, session, socket)
  end

  def mount(_params, session, socket) do
    mount(%{"q" => "", "offset" => 0}, session, socket)
  end

  def handle_params(params, session, socket) do
    IO.inspect(params)
    {:ok, socket} = mount(params, session, socket)
    {:noreply, socket}
  end
end
