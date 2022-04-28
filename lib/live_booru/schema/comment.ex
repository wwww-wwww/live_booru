defmodule LiveBooru.Comment do
  use Ecto.Schema

  schema "comments" do
    field :text, :string

    belongs_to :image, LiveBooru.Image
    belongs_to :user, LiveBooru.Accounts.User

    timestamps()
  end
end
