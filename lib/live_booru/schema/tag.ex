defmodule LiveBooru.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  alias LiveBooru.Repo

  schema "tags" do
    field :name, :string

    field :type, Ecto.Enum,
      values: [:general, :meta, :meta_system, :copyright, :character, :artist],
      default: :general

    field :description, :string

    field :locked, :boolean, default: false

    many_to_many :images, LiveBooru.Image, join_through: LiveBooru.ImagesTags

    has_many :changes, LiveBooru.TagChange

    belongs_to :tag, LiveBooru.Tag
    has_many :aliases, LiveBooru.Tag, foreign_key: :tag_id

    belongs_to :parent, LiveBooru.Tag
    has_many :children, LiveBooru.Tag, foreign_key: :parent_id
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

  def parents(nil), do: []
  def parents(tag), do: [tag] ++ parents(Repo.preload(tag, :parent).parent)

  def root(nil), do: nil
  def root(tag), do: root(Repo.preload(tag, :parent).parent) || tag

  def children(tag),
    do: [tag] ++ List.flatten(Enum.map(Repo.preload(tag, :children).children, &children(&1)))
end
