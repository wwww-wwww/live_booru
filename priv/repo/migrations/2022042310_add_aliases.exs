defmodule LiveBooru.Repo.Migrations.AddAliases do
  use Ecto.Migration

  def change do
    alter table(:tags) do
      add :tag_id, references(:tags, on_delete: :delete_all)
    end
  end
end
