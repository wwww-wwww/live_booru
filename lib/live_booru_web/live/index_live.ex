defmodule LiveBooruWeb.IndexLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.{Repo, Tag, Image}

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

  @re_search ~r/((?:-){0,1}(?:\"(?:\\(?:\\\\)*\")+(?:[^\\](?:\\(?:\\\\)*\")+|[^\"])*\"|\"(?:[^\\](?:\\(?:\\\\)*\")+|[^\"])*\"|[^ ]+))/iu

  def search(query) do
    {terms_include, terms_exclude} =
      Regex.scan(@re_search, query)
      |> Enum.map(&Enum.at(&1, 1))
      |> Enum.map(&String.downcase(&1))
      |> Enum.map(fn term ->
        case term do
          "-" <> term ->
            {false, term}

          term ->
            {true, term}
        end
      end)
      |> Enum.map(fn {inc, term} ->
        {inc,
         if String.length(term) > 1 and String.starts_with?(term, "\"") and
              String.ends_with?(term, "\"") do
           String.slice(term, 1, String.length(term) - 2)
         else
           term
         end}
      end)
      |> Enum.map(&{elem(&1, 0), String.replace(elem(&1, 1), "\\\"", "\"")})
      |> Enum.filter(&(String.length(elem(&1, 1)) > 0))
      |> Enum.reduce({[], []}, fn {term_include, term}, {include, exclude} ->
        if term_include do
          {include ++ [term], exclude}
        else
          {include, exclude ++ [term]}
        end
      end)

    {Enum.uniq(terms_include), Enum.uniq(terms_exclude)}
  end

  def mount(%{"q" => q}, _session, socket) do
    query =
      case search(q) do
        {[], exc} ->
          query_exclude =
            from t in Tag,
              join: it in LiveBooru.ImagesTags,
              on: it.tag_id == t.id,
              where: fragment("lower(?)", t.name) in ^exc,
              select: it.image_id,
              group_by: it.image_id

          from i in Image,
            where: i.id not in subquery(query_exclude)

        {inc, exc} ->
          query =
            from t in Tag,
              join: it in LiveBooru.ImagesTags,
              on: it.tag_id == t.id,
              where: fragment("lower(?)", t.name) in ^inc,
              select: it.image_id,
              group_by: it.image_id,
              having: count() == ^length(inc)

          query_exclude =
            from t in Tag,
              join: it in LiveBooru.ImagesTags,
              on: it.tag_id == t.id,
              where: fragment("lower(?)", t.name) in ^exc,
              select: it.image_id,
              group_by: it.image_id

          from i in Image,
            join: s in subquery(query),
            on: s.image_id == i.id,
            where: i.id not in subquery(query_exclude)
      end

    images =
      Repo.all(query)
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
