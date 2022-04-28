defmodule LiveBooru.Upload do
  use Ecto.Schema

  schema "uploads" do
    field :hash, :string
    field :filesize, :integer

    belongs_to :image, LiveBooru.Image
    belongs_to :user, LiveBooru.Accounts.User

    timestamps()
  end
end
