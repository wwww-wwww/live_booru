defmodule LiveBooru.Repo.Migrations.AddUploadFiletype do
  use Ecto.Migration

  def change do
    alter table(:uploads) do
      add :filetype, :string
    end
  end
end
