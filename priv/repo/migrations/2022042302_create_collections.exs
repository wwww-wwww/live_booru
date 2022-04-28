defmodule LiveBooru.Repo.Migrations.CreateCollections do
  use Ecto.Migration

  def change do
    create table(:collections) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :type, :string

      timestamps()
    end
  end
end
