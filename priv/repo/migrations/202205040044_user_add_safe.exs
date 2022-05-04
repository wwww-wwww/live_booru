defmodule LiveBooru.Repo.Migrations.UserAddSafe do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :index_default_safe, :boolean, default: true
    end
  end
end
