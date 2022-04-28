defmodule LiveBooru.Repo.Migrations.CreateEncodeJobs do
  use Ecto.Migration

  def change do
    create table(:encode_jobs) do
      add :hash, :string, null: false
      add :tags, {:array, :string}
      add :source, :string

      add :title, :string

      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:encode_jobs, [:hash])
  end
end
