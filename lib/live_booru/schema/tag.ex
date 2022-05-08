defmodule LiveBooru.Tag do
  use Ecto.Schema
  use Arbor.Tree

  import Ecto.Changeset

  import Ecto.Query, only: [where: 3]

  alias LiveBooru.Repo

  schema "tags" do
    field :name, :string

    field :type, Ecto.Enum,
      values: [:general, :meta, :meta_system, :copyright, :character, :artist, :category],
      default: :general

    field :description, :string, default: ""

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
  def parents(%{type: :category} = tag), do: parents(Repo.preload(tag, :parent).parent)
  def parents(tag), do: [tag] ++ parents(Repo.preload(tag, :parent).parent)

  def root(nil), do: nil

  def root(tag) do
    ancestors(tag)
    |> where([q], is_nil(q.parent_id))
    |> Repo.one()
    |> Kernel.||(tag)
  end

  def fill_tree(elements, root) do
    %{
      root
      | children:
          Enum.filter(elements, &(&1.parent_id == root.id)) |> Enum.map(&fill_tree(elements, &1))
    }
  end

  def get_children(tag) do
    descendants(tag)
    |> Repo.all()
    |> fill_tree(tag)
  end
end
