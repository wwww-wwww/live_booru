defmodule LiveBooru.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add :name, :string, null: false
      add :description, :text
      add :type, :string
    end

    create unique_index(:tags, :name)
  end
end
