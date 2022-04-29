defmodule LiveBooru.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    field :text, :string

    belongs_to :image, LiveBooru.Image
    belongs_to :user, LiveBooru.Accounts.User

    timestamps()
  end

  def new(text, user, image) do
    change(%__MODULE__{}, %{text: text})
    |> put_assoc(:user, user)
    |> put_assoc(:image, image)
    |> validate_required([:user, :image])
  end
end
