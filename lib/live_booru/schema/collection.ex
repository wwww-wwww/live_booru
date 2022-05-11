defmodule LiveBooru.Collection do
  use Ecto.Schema
  import Ecto.Changeset

  schema "collections" do
    field :name, :string

    field :type, Ecto.Enum,
      values: [:general, :related, :series, :favorites, :revisions, :duplicates],
      default: :general

    belongs_to :user, LiveBooru.Accounts.User

    has_many :image_collection, LiveBooru.ImagesCollections

    many_to_many :images, LiveBooru.Image,
      join_through: LiveBooru.ImagesCollections,
      on_replace: :delete

    timestamps()
  end

  def new(user, attr \\ %{}) do
    %__MODULE__{}
    |> change(attr)
    |> put_assoc(:user, user)
    |> LiveBooru.Repo.insert()
  end
end
