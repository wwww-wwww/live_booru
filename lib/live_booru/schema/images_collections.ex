defmodule LiveBooru.ImagesCollections do
  use Ecto.Schema
  import Ecto.Changeset

  schema "images_collections" do
    belongs_to :image, LiveBooru.Image
    belongs_to :collection, LiveBooru.Collection

    timestamps()
  end

  def new(collection, image) do
    %__MODULE__{}
    |> change()
    |> put_assoc(:collection, collection)
    |> put_assoc(:image, image)
    |> unique_constraint([:image_id, :collection_id])
  end
end
