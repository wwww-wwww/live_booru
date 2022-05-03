defmodule LiveBooru.Repo.Migrations.AddCollectionName do
  use Ecto.Migration

  def change do
    alter table(:collections) do
      add :name, :string
    end
  end
end
