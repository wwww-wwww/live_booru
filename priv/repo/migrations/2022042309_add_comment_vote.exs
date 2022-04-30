defmodule LiveBooru.Repo.Migrations.CreateCommentVote do
  use Ecto.Migration

  def change do
    create table(:comment_votes) do
      add :comment_id, references(:comments, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all)

      add :upvote, :boolean

      timestamps()
    end

    create unique_index(:comment_votes, [:comment_id, :user_id])
  end
end
