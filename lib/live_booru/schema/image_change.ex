defmodule LiveBooru.ImageChange do
  use Ecto.Schema

  schema "image_changes" do
    belongs_to :user, LiveBooru.Accounts.User
    belongs_to :image, LiveBooru.Image

    field :source, :string
    field :source_prev, :string

    field :tags, {:array, :integer}
    field :tags_added, {:array, :integer}
    field :tags_removed, {:array, :integer}

    timestamps()
  end
end
