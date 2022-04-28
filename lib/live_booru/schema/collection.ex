defmodule LiveBooru.Collection do
  use Ecto.Schema

  schema "collections" do
    field :type, Ecto.Enum, values: [:series, :favorites, :revisions, :duplicates]

    belongs_to :user, LiveBooru.Accounts.User

    many_to_many :images, LiveBooru.Image,
      join_through: LiveBooru.ImagesCollections,
      on_replace: :delete

    timestamps()
  end
end
