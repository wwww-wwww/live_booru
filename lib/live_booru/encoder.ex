defmodule LiveBooru.Encoder do
  use GenServer

  import Ecto.Query, only: [from: 2]

  alias LiveBooru.{WorkerManager, EncoderManager, Uploader, Repo, Upload, Image, Tag, Collection}

  defstruct id: nil, active: false

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: String.to_atom("#{__MODULE__}_#{opts[:id]}"))
  end

  def init(opts) do
    send(self(), :startup)
    {:ok, %__MODULE__{id: {__MODULE__, opts[:id]}}}
  end

  def handle_info(:startup, state) do
    GenServer.call(EncoderManager, {:register, self()})

    GenServer.cast(self(), :loop)
    {:noreply, state}
  end

  def handle_cast(:loop, state) do
    case WorkerManager.pop(EncoderManager, sort_by: &{not &1.is_jxl, &1.id}, order: :asc) do
      :empty ->
        {:noreply, %{state | active: false}}

      job ->
        LiveBooruWeb.QueueLive.update()

        if Uploader.exists?(job.hash) do
          WorkerManager.finish(EncoderManager, job)
        else
          in_path = Path.join("tmp", job.hash)

          if LiveBooru.Jxl.path_is_jxl?(in_path) do
            decoded = in_path <> ".png"

            case Uploader.decode_jxl(in_path, decoded, &Uploader.get_hash/1) do
              {:ok, png_hash} ->
                # if png of jxl exists, remember jxl
                if upload = Repo.get_by(Upload, hash: png_hash) |> Repo.preload(:image) do
                  create_upload(upload.image, job)
                  File.rm(in_path)
                  WorkerManager.finish(EncoderManager, job)
                else
                  if pixels_hash = Uploader.get_pixels_hash(decoded) do
                    # if pixels of jxl exists, remember jxl
                    if image = Repo.get_by(Image, pixels_hash: pixels_hash) do
                      create_upload(image, job)
                      File.rm(in_path)
                      WorkerManager.finish(EncoderManager, job)
                    else
                      create_image(job, job.hash, pixels_hash, in_path, decoded)
                    end
                  end
                end

                File.rm(decoded)

              err ->
                IO.inspect(err)
            end
          else
            case Uploader.get_format(in_path) do
              "JPEG" -> true
              "PNG" -> true
              "GIF" -> true
              "WEBP" -> true
              _ -> nil
            end
            |> case do
              nil ->
                File.rm(in_path)
                WorkerManager.finish(EncoderManager, job)

              true ->
                if pixels_hash = Uploader.get_pixels_hash(in_path) do
                  # if pixels of image exists, remember image
                  if image = Repo.get_by(Image, pixels_hash: pixels_hash) do
                    create_upload(image, job)
                    File.rm(in_path)
                    WorkerManager.finish(EncoderManager, job)
                  else
                    case System.cmd("python3", ["encode.py", in_path, in_path <> ".f.jxl"]) do
                      {output, 0} ->
                        [version, params | _] = String.split(output, "\n")

                        if hash = Uploader.get_hash(in_path <> ".f.jxl") do
                          decoded = in_path <> ".f.jxl.png"

                          case Uploader.decode_jxl(
                                 in_path <> ".f.jxl",
                                 decoded,
                                 &Uploader.get_pixels_hash/1
                               ) do
                            {:ok, new_pixels_hash} ->
                              create_image(
                                job,
                                hash,
                                new_pixels_hash,
                                in_path <> ".f.jxl",
                                decoded,
                                {version, params},
                                fn image ->
                                  create_upload(image, job)
                                  File.rm(in_path)
                                  File.rm(decoded)
                                end
                              )

                            err ->
                              IO.inspect(err)
                          end

                          File.rm(decoded)
                        else
                          IO.inspect(output)
                        end

                      err ->
                        IO.inspect(err)
                    end
                  end
                end
            end
          end
        end

        GenServer.cast(self(), :loop)
        LiveBooruWeb.QueueLive.update()

        {:noreply, %{state | active: true}}
    end
  end

  def create_image(
        job,
        hash,
        pixels_hash,
        file,
        decoded,
        {version, params} \\ {nil, nil},
        fun \\ nil
      ) do
    out_path = Path.join(LiveBooru.files_root(), hash) <> ".jxl"

    thumb_path = Path.join(LiveBooru.thumb_root(), hash) <> ".webp"

    {thumb, thumb_hash} = create_thumb(decoded, thumb_path)

    query = from i in Image, where: i.thumb_hash == ^thumb_hash

    jxlinfo = LiveBooru.Jxl.info(file)
    {width, height} = LiveBooru.AutoTag.dimensions(jxlinfo)

    {dupes, tags} =
      case Repo.all(query) do
        [] -> {[], job.tags}
        dupes -> {dupes, job.tags ++ ["Potential Duplicate"]}
      end

    tags =
      tags
      |> LiveBooru.AutoTag.tag(jxlinfo, job, decoded)
      |> Stream.map(fn tag_name ->
        case Repo.get_tag(tag_name) do
          nil -> Tag.new(tag_name, :general)
          tag -> Ecto.Changeset.change(tag)
        end
        |> Repo.insert_or_update()
        |> case do
          {:ok, tag} -> tag
          _ -> Repo.get_by(Tag, name: tag_name)
        end
      end)
      |> Stream.filter(&(!is_nil(&1)))
      |> Enum.map(&Tag.parents(&1))
      |> List.flatten()
      |> Enum.uniq_by(& &1.id)
      |> Enum.sort_by(& &1.name)

    %Image{
      title: job.title,
      hash: hash,
      pixels_hash: pixels_hash,
      path: out_path,
      filesize: File.stat!(file).size,
      width: width,
      height: height,
      source: job.source,
      info: jxlinfo,
      encoder_version: version,
      encoder_params: params,
      thumb: thumb,
      thumb_hash: thumb_hash
    }
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:user, job.user)
    |> Ecto.Changeset.put_assoc(:tags, tags)
    |> Repo.insert()
    |> case do
      {:ok, image} ->
        case File.cp(file, out_path) do
          :ok ->
            File.rm(file)
            if fun, do: fun.(image)
            WorkerManager.finish(EncoderManager, job)

          err ->
            IO.inspect(err)
        end

        dupes
        |> Enum.each(fn dupe ->
          %Collection{type: :duplicates}
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.put_assoc(:images, [dupe, image])
          |> Repo.insert()
        end)

      {:error, cs} ->
        IO.inspect(cs)
    end
  end

  def create_upload(image, job) do
    file = Path.join("tmp", job.hash)

    %Upload{hash: job.hash, filesize: File.stat!(file).size}
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.put_assoc(:user, job.user)
    |> Ecto.Changeset.put_assoc(:image, image)
    |> Repo.insert()
  end

  def create_thumb(image, thumb_path) do
    case System.cmd("python3", ["thumb.py", image, thumb_path]) do
      {_, 0} ->
        if File.exists?(thumb_path) do
          {thumb_path, Uploader.get_pixels_hash(thumb_path)}
        else
          {nil, nil}
        end

      _ ->
        {nil, nil}
    end
  end

  def get(), do: WorkerManager.get(EncoderManager)

  def notify(), do: WorkerManager.notify(EncoderManager)
end
