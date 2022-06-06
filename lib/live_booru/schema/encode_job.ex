defmodule LiveBooru.EncodeJob do
  use Ecto.Schema

  schema "encode_jobs" do
    field :hash, :string
    field :path, :string
    field :tags, {:array, :string}
    field :source, :string

    field :is_jxl, :boolean

    field :title, :string

    belongs_to :user, LiveBooru.Accounts.User

    timestamps()
  end
end
