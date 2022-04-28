defmodule LiveBooru.Vote do
  use Ecto.Schema

  schema "votes" do
    field :upvote, :boolean

    belongs_to :image, LiveBooru.Image
    belongs_to :user, LiveBooru.Accounts.User

    timestamps()
  end
end
