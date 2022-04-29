defmodule LiveBooru.Repo do
  use Ecto.Repo,
    otp_app: :live_booru,
    adapter: Ecto.Adapters.Postgres

  alias LiveBooru.{Repo, ImagesTags}

  import Ecto.Query, only: [from: 2]

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
end
