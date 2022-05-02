defmodule LiveBooru.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tags" do
    field :name, :string

    field :type, Ecto.Enum,
      values: [:general, :meta, :meta_system, :copyright, :character, :artist],
      default: :general

    field :description, :string

    field :locked, :boolean, default: false

    many_to_many :images, LiveBooru.Image, join_through: LiveBooru.ImagesTags
    has_many :aliases, LiveBooru.Tag

    has_many :changes, LiveBooru.TagChange

    belongs_to :tag, LiveBooru.Tag
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :type, :description])
    |> validate_required([:name, :type])
    |> unique_constraint(:name)
  end

  def new(name, type \\ :general) do
    changeset(%__MODULE__{}, %{name: name, type: type})
  end
end
