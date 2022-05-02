defmodule LiveBooru.Repo.Migrations.AddIsJxl do
  use Ecto.Migration

  def change do
    alter table(:encode_jobs) do
      add :is_jxl, :boolean
    end
  end
end
