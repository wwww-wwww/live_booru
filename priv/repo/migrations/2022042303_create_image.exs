defmodule LiveBooru.Repo.Migrations.CreateImages do
  use Ecto.Migration

  def change do
    create table(:images) do
      add :hash, :string, null: false
      add :pixels_hash, :string, null: false
      add :path, :string
      add :filesize, :integer

      add :source, :string
      add :thumb, :string
      add :thumb_hash, :string

      add :encoder_params, :string
      add :encoder_version, :string
      add :info, :text

      add :title, :string

      add :user_id, references(:users, on_delete: :nothing)

      timestamps()
    end

    create index(:images, :thumb_hash)

    create unique_index(:images, :hash)
    create unique_index(:images, :pixels_hash)

    create table(:uploads) do
      add :hash, :string, null: false
      add :filesize, :integer

      add :image_id, references(:images, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :nothing)

      timestamps()
    end

    create unique_index(:uploads, :hash)

    create table(:images_tags) do
      add :image_id, references(:images, on_delete: :delete_all)
      add :tag_id, references(:tags, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:images_tags, [:image_id, :tag_id])

    create table(:images_collections) do
      add :image_id, references(:images, on_delete: :delete_all)
      add :collection_id, references(:collections, on_delete: :delete_all)

      timestamps()
    end

    create unique_index(:images_collections, [:image_id, :collection_id])

    create table(:comments) do
      add :text, :string
      add :image_id, references(:images, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :nothing)

      timestamps()
    end

    create table(:votes) do
      add :image_id, references(:images, on_delete: :nothing)
      add :user_id, references(:users, on_delete: :nothing)

      add :upvote, :boolean

      timestamps()
    end

    create unique_index(:votes, [:image_id, :user_id])
  end
end
