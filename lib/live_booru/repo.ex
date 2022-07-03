defmodule LiveBooru.Repo do
  use Ecto.Repo,
    otp_app: :live_booru,
    adapter: Ecto.Adapters.Postgres

  @limit 40

  alias LiveBooru.Accounts.User
  alias LiveBooru.{Repo, ImagesTags, Tag, Image, Collection, ImagesCollections, ImageVote}

  import Ecto.Query,
    only: [
      from: 1,
      from: 2,
      limit: 2,
      offset: 2,
      order_by: 2,
      dynamic: 1,
      dynamic: 2
    ]

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

  @re_search ~r/((?:-{0,1}|[^ ]*?:)\"(?:\\\"|.)*?\"|[^ ]+)/iu

  def separate_terms(query) do
    Regex.scan(@re_search, query)
    |> Enum.map(&Enum.at(&1, 1))
  end

  def parse_terms(query) do
    {terms_include, terms_exclude, terms_extra, order} =
      separate_terms(query)
      |> Enum.map(&String.downcase(&1))
      |> Enum.map(fn term ->
        case term do
          "user:" <> term -> {:user, term}
          "user_id:" <> term -> {:user_id, term}
          "collection:" <> term -> {:collection, term}
          "width:>=" <> term -> {{:width, :>=}, term}
          "width:<=" <> term -> {{:width, :<=}, term}
          "width:>" <> term -> {{:width, :>}, term}
          "width:<" <> term -> {{:width, :<}, term}
          "width:" <> term -> {{:width, :==}, term}
          "height:>=" <> term -> {{:height, :>=}, term}
          "height:<=" <> term -> {{:height, :<=}, term}
          "height:>" <> term -> {{:height, :>}, term}
          "height:<" <> term -> {{:height, :<}, term}
          "height:" <> term -> {{:height, :==}, term}
          "order:" <> term -> {:order, term}
          "-" <> term -> {:exclude, term}
          term -> {:include, term}
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
      |> Enum.reduce({[], [], [], nil}, fn {term_type, term}, {include, exclude, extra, order} ->
        case term_type do
          :include -> {include ++ [term], exclude, extra, order}
          :exclude -> {include, exclude ++ [term], extra, order}
          :order -> {include, exclude, extra, term}
          _ -> {include, exclude, extra ++ [{term_type, term}], order}
        end
      end)

    {Enum.uniq(terms_include), Enum.uniq(terms_exclude), Enum.uniq(terms_extra), order}
  end

  def filter(query, opts \\ []) do
    count = LiveBooru.Repo.aggregate(query, :count)

    query =
      case opts[:order] do
        "oldest" ->
          order_by(query, asc: :inserted_at)

        "score" <> order ->
          order =
            case order do
              "_asc" -> :asc
              "_desc" -> :desc
              _ -> :desc
            end

          from(i in query,
            left_join: iv in ImageVote,
            on: i.id == iv.image_id,
            group_by: i.id,
            order_by: [
              {^order,
               sum(
                 fragment(
                   "case when ? then 0 when ? then 1 else -1 end",
                   is_nil(iv.upvote),
                   iv.upvote
                 )
               )},
              desc: i.inserted_at
            ]
          )

        _ ->
          order_by(query, desc: :inserted_at)
      end

    results =
      opts
      |> Map.new()
      |> case do
        %{offset: n} -> offset(query, ^n)
        _ -> query
      end
      |> limit(@limit)
      |> Repo.all()

    {results, %{count: count, pages: max(ceil(count / @limit), 1), limit: @limit}}
  end

  def search(_, _ \\ [])

  def search("", opts) do
    query = from(i in Image)

    filter(query, opts)
  end

  def search(query, opts) do
    {inc, exc, extra, order} = Repo.parse_terms(query)

    query_exclude_aliases =
      from t in Tag,
        where: not is_nil(t.tag_id) and fragment("lower(?)", t.name) in ^exc,
        select: t.tag_id

    query_exclude =
      from t in Tag,
        join: it in LiveBooru.ImagesTags,
        on: it.tag_id == t.id,
        where: fragment("lower(?)", t.name) in ^exc or t.id in subquery(query_exclude_aliases),
        select: it.image_id,
        group_by: it.image_id

    query =
      case inc do
        [] ->
          from i in Image, where: i.id not in subquery(query_exclude)

        inc ->
          query_aliases =
            from t in Tag,
              where: not is_nil(t.tag_id) and fragment("lower(?)", t.name) in ^inc,
              select: t.tag_id

          query =
            from t in Tag,
              join: it in LiveBooru.ImagesTags,
              on: it.tag_id == t.id,
              where: fragment("lower(?)", t.name) in ^inc or t.id in subquery(query_aliases),
              select: it.image_id,
              group_by: it.image_id,
              having: count() == ^length(inc)

          from i in Image,
            join: s in subquery(query),
            on: s.image_id == i.id,
            where: i.id not in subquery(query_exclude)
      end

    extra_conditions =
      Enum.reduce(extra, dynamic(true), fn term, dynamic ->
        case term do
          {:user, username} ->
            query =
              from i in Image,
                join: u in User,
                on: u.id == i.user_id,
                where: ilike(u.name, ^username),
                select: i.id

            dynamic([q], ^dynamic and q.id in subquery(query))

          {:user_id, user_id} ->
            case Integer.parse(user_id) do
              {user_id, _} -> dynamic([q], ^dynamic and q.user_id == ^user_id)
              _ -> dynamic
            end

          {:collection, collection_id} ->
            case Integer.parse(collection_id) do
              {collection_id, _} ->
                query =
                  from c in ImagesCollections,
                    where: c.collection_id == ^collection_id,
                    select: c.image_id

                dynamic([q], ^dynamic and q.id in subquery(query))

              _ ->
                dynamic
            end

          {{:width, comparator}, width} ->
            case Integer.parse(width) do
              {width, _} ->
                # ideally something like Kernel.apply(Kernel, comparator, [q.width, ^width]), but for query
                case comparator do
                  :> -> dynamic([q], ^dynamic and q.width > ^width)
                  :< -> dynamic([q], ^dynamic and q.width < ^width)
                  :>= -> dynamic([q], ^dynamic and q.width >= ^width)
                  :<= -> dynamic([q], ^dynamic and q.width <= ^width)
                  :== -> dynamic([q], ^dynamic and q.width == ^width)
                end

              _ ->
                dynamic
            end

          {{:height, comparator}, height} ->
            case Integer.parse(height) do
              {height, _} ->
                case comparator do
                  :> -> dynamic([q], ^dynamic and q.height > ^height)
                  :< -> dynamic([q], ^dynamic and q.height < ^height)
                  :>= -> dynamic([q], ^dynamic and q.height >= ^height)
                  :<= -> dynamic([q], ^dynamic and q.height <= ^height)
                  :== -> dynamic([q], ^dynamic and q.height == ^height)
                end

              _ ->
                dynamic
            end
        end
      end)

    query = from query, where: ^extra_conditions

    filter(query, Keyword.merge(opts, order: order))
  end

  def build_search_tags(query, category \\ false) do
    query_aliases =
      from t in Tag,
        where: ilike(t.name, ^"%#{query}%") and not is_nil(t.tag_id)

    aliases_tags =
      from t in Tag,
        join: a in subquery(query_aliases),
        on: t.id == a.tag_id,
        select: t.id

    if category do
      from t in Tag,
        where:
          (ilike(t.name, ^"%#{query}%") and is_nil(t.tag_id)) or t.id in subquery(aliases_tags)
    else
      from t in Tag,
        where:
          ((ilike(t.name, ^"%#{query}%") and is_nil(t.tag_id)) or t.id in subquery(aliases_tags)) and
            t.type != :category
    end
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

  def get_favorites(%{id: user_id}) do
    from(c in Collection,
      where: c.user_id == ^user_id and c.type == :favorites,
      order_by: [asc: c.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  def add_collection(collection, image) do
    ImagesCollections.new(collection, image)
    |> Repo.insert()
  end

  def get_favorite(nil, _), do: nil

  def get_favorite(%{id: user_id}, %{id: image_id}) do
    from(ic in ImagesCollections,
      join: c in Collection,
      on: c.id == ic.collection_id,
      where: c.user_id == ^user_id and ic.image_id == ^image_id and c.type == :favorites,
      order_by: [asc: c.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  def count_favorites(%{id: image_id}) do
    from(ic in ImagesCollections,
      join: c in Collection,
      on: c.id == ic.collection_id,
      where: c.type == :favorites and ic.image_id == ^image_id
    )
    |> Repo.aggregate(:count)
  end

  def get_collections(%{id: user_id}, %{id: image_id}) do
    from(ic in ImagesCollections,
      join: c in Collection,
      on: c.id == ic.collection_id,
      where: c.user_id == ^user_id and ic.image_id == ^image_id,
      select: {c.id, ic}
    )
    |> Repo.all()
    |> Map.new()
  end

  def get_collections(%User{id: user_id}) do
    from(c in Collection,
      where: c.user_id == ^user_id,
      order_by: [asc: c.inserted_at]
    )
    |> Repo.all()
  end

  def get_collections(%Image{id: image_id}) do
    from(ic in ImagesCollections,
      join: c in Collection,
      on: c.id == ic.collection_id,
      where: c.type != :favorites and ic.image_id == ^image_id,
      select: c
    )
    |> Repo.all()
  end
end
