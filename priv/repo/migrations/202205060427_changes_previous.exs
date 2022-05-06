defmodule LiveBooru.Repo.Migrations.ChangesPrevious do
  use Ecto.Migration

  def change do
    alter table(:tag_changes) do
      add :description_prev, :text
    end

    alter table(:image_changes) do
      add :source_prev, :text
      add :tags_added, {:array, :integer}
      add :tags_removed, {:array, :integer}
    end
  end
end
