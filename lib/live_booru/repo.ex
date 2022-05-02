defmodule LiveBooru.Repo do
  use Ecto.Repo,
    otp_app: :live_booru,
    adapter: Ecto.Adapters.Postgres

  @limit 40

  alias LiveBooru.{Repo, ImagesTags, Tag, Image}

  import Ecto.Query, only: [from: 1, from: 2, limit: 2, offset: 2, order_by: 2]

  # input: [%Tag{}]
  # output: [{%Tag{}, n}]
  def count_tags(tags) do
    tag_ids = Enum.map(tags, & &1.id)

    count_query =
      from t in ImagesTags,
        where: t.tag_id in ^tag_ids,
        select: {t.tag_id, count(t.tag_id)},
        group_by: t.tag_id

    counts =
      Repo.all(count_query)
      |> Map.new()

    Enum.map(tags, &{&1, Map.get(counts, &1.id, 0)})
  end

  @re_search ~r/((?:-){0,1}(?:\"(?:\\(?:\\\\)*\")+(?:[^\\](?:\\(?:\\\\)*\")+|[^\"])*\"|\"(?:[^\\](?:\\(?:\\\\)*\")+|[^\"])*\"|[^ ]+))/iu

  def parse_terms(query) do
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

  def filter(query, opts \\ []) do
    query = order_by(query, desc: :id)

    query =
      case Keyword.get(opts, :order, :date) do
        :date -> order_by(query, desc: :inserted_at)
      end

    count = LiveBooru.Repo.aggregate(query, :count)

    results =
      opts
      |> Map.new()
      |> case do
        %{offset: n} -> offset(query, ^n)
        _ -> query
      end
      |> limit(@limit)
      |> Repo.all()

    {results, %{count: count, pages: ceil(count / @limit), limit: @limit}}
  end

  def search(_, _ \\ [])

  def search("", opts) do
    query = from(i in Image)

    filter(query, opts)
  end

  def search(query, opts) do
    {inc, exc} = Repo.parse_terms(query)

    query =
      case {inc, exc} do
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

    filter(query, opts)
  end

  def build_search_tags(query) do
    query_aliases =
      from t in Tag,
        where: ilike(t.name, ^"%#{query}%") and not is_nil(t.tag_id)

    aliases_tags =
      from t in Tag,
        join: a in subquery(query_aliases),
        on: t.id == a.tag_id,
        select: t.id

    from t in Tag,
      where: (ilike(t.name, ^"%#{query}%") and is_nil(t.tag_id)) or t.id in subquery(aliases_tags)
  end

  def get_tag(name) do
    query_aliases =
      from t in Tag,
        where: ilike(t.name, ^name) and not is_nil(t.tag_id)

    aliases_tags =
      from t in Tag,
        join: a in subquery(query_aliases),
        on: t.id == a.tag_id,
        select: t.id

    query =
      from t in Tag,
        where: (ilike(t.name, ^name) and is_nil(t.tag_id)) or t.id in subquery(aliases_tags)

    Repo.one(query)
  end
end
