defmodule LiveBooru do
  alias LiveBooru.{Repo, Tag, Image, AutoTag}

  def files_root(), do: Application.get_env(:live_booru, :files_root)
  def thumb_root(), do: Application.get_env(:live_booru, :thumb_root)

  def default_tags() do
    [
      {"NSFW", :meta},
      {"Suggestive", :meta},
      {"Original", :copyright},
      {"Cat", :general},
      {"Dog", :general},
      {"Potential Duplicate", :meta}
    ]
    |> Enum.each(&Repo.insert(Tag.new(elem(&1, 0), elem(&1, 1))))
  end

  def delete_images() do
    Repo.all(Image) |> Enum.each(&Repo.delete(&1))
  end

  def test() do
    Repo.insert(Tag.new("test", :general))
    |> case do
      {:ok, r} -> r
      err -> err
    end
  end

  def jxlinfo() do
    Repo.all(Image)
    |> Enum.each(fn image ->
      Ecto.Changeset.change(image, %{info: LiveBooru.Jxl.info(image.path)})
      |> Repo.update()
    end)
  end

  def autotag() do
    Repo.all(Image)
    |> Repo.preload(:tags)
    |> Enum.each(fn image ->
      tags =
        image.tags
        |> Enum.map(& &1.name)
        |> LiveBooru.AutoTag.tag(image.info, nil, nil)
        |> Enum.map(&Repo.get_by(Tag, name: &1))
        |> Enum.map(&Tag.parents(&1))
        |> List.flatten()

      image =
        Ecto.Changeset.change(image)
        |> Ecto.Changeset.put_assoc(:tags, tags)
        |> Repo.update()
    end)
  end

  def add_dimensions() do
    Repo.all(Image)
    |> Enum.each(fn image ->
      {w, h} = AutoTag.dimensions(image.info)

      Ecto.Changeset.change(image, %{width: w, height: h})
      |> Repo.update()
    end)
  end
end
