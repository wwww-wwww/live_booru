defmodule LiveBooru.ImagesCollections do
  use Ecto.Schema

  @primary_key false
  schema "images_collections" do
    belongs_to :image, LiveBooru.Image
    belongs_to :collection, LiveBooru.Collection

    timestamps()
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> Ecto.Changeset.cast(params, [:image_id, :collection_id])
    |> Ecto.Changeset.validate_required([:image_id, :collection_id])
  end
end
