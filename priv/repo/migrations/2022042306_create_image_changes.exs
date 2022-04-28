defmodule LiveBooru.Repo.Migrations.CreateImageChanges do
  use Ecto.Migration

  def change do
    create table(:image_changes) do
      add :image_id, references(:images, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :nothing)

      add :source, :string
      add :tags, {:array, :integer}

      timestamps()
    end
  end
end
