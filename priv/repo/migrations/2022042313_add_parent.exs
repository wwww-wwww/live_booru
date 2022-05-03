defmodule LiveBooru.Repo.Migrations.AddParent do
  use Ecto.Migration

  def change do
    alter table(:tags) do
      add :parent_id, references(:tags, on_delete: :nilify_all)
    end
  end
end
