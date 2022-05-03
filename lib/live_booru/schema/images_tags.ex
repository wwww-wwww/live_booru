defmodule LiveBooru.ImagesTags do
  use Ecto.Schema

  schema "images_tags" do
    belongs_to :image, LiveBooru.Image
    belongs_to :tag, LiveBooru.Tag

    timestamps()
  end
end
