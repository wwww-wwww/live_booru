defmodule LiveBooru.Repo.Migrations.UserAddTheme do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :theme, :string
    end
  end
end
