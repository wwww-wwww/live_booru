defmodule LiveBooru.TagChange do
  use Ecto.Schema

  schema "tag_changes" do
    belongs_to :user, LiveBooru.Accounts.User
    belongs_to :tag, LiveBooru.Tag

    field :description, :string

    timestamps()
  end
end
