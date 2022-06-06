defmodule LiveBooru.Repo.Migrations.AddJobPath do
  use Ecto.Migration

  def change do
    alter table(:encode_jobs) do
      add :path, :string
    end
  end
end
