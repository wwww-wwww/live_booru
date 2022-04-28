defmodule LiveBooru.Repo.Migrations.AddTagsLocked do
  use Ecto.Migration

  def change do
    alter table(:tags) do
      add :locked, :boolean
    end
  end
end
