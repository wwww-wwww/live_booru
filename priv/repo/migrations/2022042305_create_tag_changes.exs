defmodule LiveBooru.Repo.Migrations.CreateTagChanges do
  use Ecto.Migration

  def change do
    create table(:tag_changes) do
      add :tag_id, references(:tags, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :nothing)

      add :description, :text

      timestamps()
    end
  end
end
