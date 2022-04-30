defmodule LiveBooru.ImageVote do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]

  alias LiveBooru.Repo

  schema "votes" do
    field :upvote, :boolean

    belongs_to :image, LiveBooru.Image
    belongs_to :user, LiveBooru.Accounts.User

    timestamps()
  end

  def new(user, image, up) do
    change(%__MODULE__{}, %{upvote: up})
    |> put_assoc(:user, user)
    |> put_assoc(:image, image)
    |> validate_required([:upvote, :user, :image])
  end

  def add(user, image, up) do
    case Repo.get_by(__MODULE__, user_id: user.id, image_id: image.id) do
      nil ->
        new(user, image, up)
        |> Repo.insert()
        |> case do
          {:ok, _} -> {:ok, up}
          err -> err
        end

      vote ->
        if vote.upvote == up do
          Repo.delete(vote)
          |> case do
            {:ok, _} -> {:ok, nil}
            err -> err
          end
        else
          change(vote, %{upvote: up})
          |> Repo.update()
          |> case do
            {:ok, _} -> {:ok, up}
            err -> err
          end
        end
    end
  end

  def get_votes(%{id: id}) do
    query_all =
      from iv in __MODULE__,
        where: iv.image_id == ^id,
        group_by: iv.upvote,
        select: {iv.upvote, count(iv.id)}

    counts =
      Repo.all(query_all)
      |> Map.new()

    {Map.get(counts, true, 0), Map.get(counts, false, 0)}
  end

  def get_score(image) do
    {up, down} = get_votes(image)
    up - down
  end
end
