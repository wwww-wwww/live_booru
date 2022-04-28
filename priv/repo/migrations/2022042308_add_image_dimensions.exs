defmodule LiveBooru.Repo.Migrations.AddImageDimensions do
  use Ecto.Migration

  def change do
    alter table(:images) do
      add :width, :integer
      add :height, :integer
    end
  end
end
