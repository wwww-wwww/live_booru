defmodule LiveBooru.CommentVote do
  use Ecto.Schema
  import Ecto.Changeset

  alias LiveBooru.Repo

  schema "comment_votes" do
    field :upvote, :boolean

    belongs_to :comment, LiveBooru.Comment
    belongs_to :user, LiveBooru.Accounts.User

    timestamps()
  end

  def new(user, comment, up) do
    change(%__MODULE__{}, %{upvote: up})
    |> put_assoc(:user, user)
    |> put_assoc(:comment, comment)
    |> validate_required([:upvote, :user, :comment])
    |> unique_constraint([:comment_id, :user_id])
  end

  def add(user, comment, up) do
    case Repo.get_by(__MODULE__, user_id: user.id, comment_id: comment.id) do
      nil ->
        new(user, comment, up)
        |> Repo.insert()

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
        end
    end
  end
end
