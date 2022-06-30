defmodule LiveBooruWeb.SearchLive do
  use LiveBooruWeb, :live_component
  # use Phoenix.LiveView,
  #  container: {:div, class: __MODULE__ |> to_string() |> String.split(".") |> Enum.at(-1)}

  # import Phoenix.LiveView.Helpers
  # alias LiveBooruWeb.Router.Helpers, as: Routes

  import Ecto.Query, only: [from: 2, limit: 2]

  alias LiveBooru.Repo

  def render(assigns) do
    LiveBooruWeb.PageView.render("search.html", assigns)
  end

  def mount(_, _, socket) do
    # socket = assign(socket, :q, "")
    {:ok, socket}
  end

  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> put_flash(:search, query)
      |> push_redirect(to: Routes.live_path(socket, LiveBooruWeb.IndexLive, q: query))

    {:noreply, socket}
  end

  defp remove_quotes(query) do
    case query do
      "\"" <> a ->
        if String.ends_with?(a, "\"") do
          String.slice(a, 0..-2)
        else
          a
        end

      _ ->
        query
    end
  end

  defp strip_modifier(query) do
    case query do
      "-" <> query -> strip_modifier(query)
      "\"" <> query -> strip_modifier(query)
      query -> query
    end
  end

  def handle_event("suggest", %{"query" => query}, socket) do
    terms = Repo.separate_terms(query <> ".")

    socket =
      terms
      |> Enum.take(-2)
      |> case do
        ["\"" <> a, b] ->
          if not String.ends_with?(a, "\"") do
            [a <> " " <> b]
          else
            [b]
          end

        a ->
          a
      end
      |> Enum.at(-1)
      |> String.slice(0..-2)
      |> strip_modifier()
      |> case do
        "" ->
          assign(socket, suggestions: [])

        incomplete ->
          subq =
            from(t in Repo.build_search_tags(incomplete),
              order_by: t.name
            )

          complete = Enum.drop(terms, -1) |> Enum.map(&remove_quotes/1)

          suggestions =
            from(t in subq, where: fragment("lower(?)", t.name) not in ^complete)
            |> limit(10)

          suggestions =
            from(t in suggestions,
              join: it in LiveBooru.ImagesTags,
              on: it.tag_id == t.id,
              group_by: [t.name, t.type],
              select: {t.name, t.type, count(t.name)}
            )
            |> Repo.all()

          assign(socket, suggestions: suggestions)
      end

    {:noreply, socket}
  end
end
