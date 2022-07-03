defmodule LiveBooruWeb.SearchLive do
  use LiveBooruWeb, :live_component
  # use Phoenix.LiveView,
  #  container: {:div, class: __MODULE__ |> to_string() |> String.split(".") |> Enum.at(-1)}

  # import Phoenix.LiveView.Helpers
  # alias LiveBooruWeb.Router.Helpers, as: Routes

  import Ecto.Query, only: [from: 2]

  alias LiveBooru.Repo

  @meta_tags [
    {"user:", :meta, ""},
    {"user_id:", :meta, ""},
    {"collection:", :meta, ""},
    {"width:>=", :meta, ""},
    {"width:<=", :meta, ""},
    {"width:>", :meta, ""},
    {"width:<", :meta, ""},
    {"width:", :meta, ""},
    {"height:>=", :meta, ""},
    {"height:<=", :meta, ""},
    {"height:>", :meta, ""},
    {"height:<", :meta, ""},
    {"height:", :meta, ""},
    {"order:", :meta, ""}
  ]

  def render(assigns) do
    LiveBooruWeb.PageView.render("search.html", assigns)
  end

  def mount(_, _, socket) do
    # socket = assign(socket, :q, "")
    {:ok, socket}
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

  defp extra_suggestions(query, suggestions) do
    (@meta_tags |> Enum.filter(&String.contains?(elem(&1, 0), query))) ++ suggestions
  end

  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> put_flash(:search, query)
      |> push_redirect(to: Routes.live_path(socket, LiveBooruWeb.IndexLive, q: query))

    {:noreply, socket}
  end

  def handle_event("suggest", %{"query" => query}, socket) do
    terms = Repo.separate_terms(query <> ".")

    socket =
      terms
      |> Enum.take(-2)
      |> Enum.map(
        &case &1 do
          "-" <> query -> query
          _ -> &1
        end
      )
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
      |> case do
        "\"" <> query -> query
        query -> query
      end
      |> case do
        "" ->
          assign(socket, suggestions: [])

        incomplete ->
          subq = from(t in Repo.build_search_tags(incomplete), order_by: t.name)

          complete = Enum.drop(terms, -1) |> Enum.map(&remove_quotes/1)

          suggestions =
            from(t in subq,
              where: fragment("lower(?)", t.name) not in ^complete,
              limit: 10
            )

          suggestions =
            from(t in suggestions,
              join: it in LiveBooru.ImagesTags,
              on: it.tag_id == t.id,
              group_by: [t.name, t.type],
              select: {t.name, t.type, count(t.name)}
            )
            |> Repo.all()

          assign(socket, suggestions: extra_suggestions(incomplete, suggestions))
      end

    {:noreply, socket}
  end
end
