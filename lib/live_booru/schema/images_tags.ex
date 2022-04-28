defmodule LiveBooru.ImagesTags do
  use Ecto.Schema

  @primary_key false
  schema "images_tags" do
    belongs_to :image, LiveBooru.Image
    belongs_to :tag, LiveBooru.Tag

    timestamps()
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> Ecto.Changeset.cast(params, [:image_id, :tag_id])
    |> Ecto.Changeset.validate_required([:image_id, :tag_id])
  end
end
