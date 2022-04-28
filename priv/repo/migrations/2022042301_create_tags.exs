defmodule LiveBooru.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add :name, :string, null: false
      add :description, :text
      add :type, :string
    end

    create unique_index(:tags, :name)

    create table(:aliases) do
      add :name, :string, null: false
      add :tag_id, references(:tags, on_delete: :delete_all)
    end

    create unique_index(:aliases, :name)
  end
end
