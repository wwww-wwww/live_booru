defmodule LiveBooru.Image do
  use Ecto.Schema

  schema "images" do
    field :hash, :string
    field :pixels_hash, :string
    field :path, :string
    field :filesize, :integer

    field :width, :integer
    field :height, :integer

    field :source, :string
    field :thumb, :string
    field :thumb_hash, :string

    field :encoder_version, :string
    field :encoder_params, :string
    field :info, :string

    field :title, :string

    belongs_to :user, LiveBooru.Accounts.User

    has_many :uploads, LiveBooru.Upload

    many_to_many :tags, LiveBooru.Tag, join_through: LiveBooru.ImagesTags, on_replace: :delete

    many_to_many :collections, LiveBooru.Collection,
      join_through: LiveBooru.ImagesCollections,
      on_replace: :delete

    has_many :votes, LiveBooru.ImageVote
    has_many :comments, LiveBooru.Comment

    has_many :changes, LiveBooru.ImageChange

    timestamps()
  end
end

defmodule LiveBooru.EncodeJob do
  use Ecto.Schema

  schema "encode_jobs" do
    field :hash, :string
    field :tags, {:array, :string}
    field :source, :string

    field :is_jxl, :boolean

    field :title, :string

    belongs_to :user, LiveBooru.Accounts.User

    timestamps()
  end
end
