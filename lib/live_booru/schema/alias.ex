defmodule LiveBooru.Alias do
  use Ecto.Schema

  schema "aliases" do
    field :name, :string
    belongs_to :tag, LiveBooru.Tag
  end
end
