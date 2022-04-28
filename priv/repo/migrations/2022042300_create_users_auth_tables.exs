defmodule LiveBooru.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :username, :string, null: false
      add :name, :string, null: false
      add :password, :string, null: false
      add :level, :integer, default: 0

      timestamps()
    end

    create unique_index(:users, [:username])

    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false

      timestamps(updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
