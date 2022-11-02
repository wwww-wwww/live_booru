defmodule LiveBooru.Encoder do
  use GenServer

  import Ecto.Query, only: [from: 2]

  alias LiveBooru.{WorkerManager, EncoderManager, Uploader, Repo, Upload, Image, Tag, Collection}

  @cjxl_args ["-q", "100", "-e", "9", "-E", "3", "-I", "100"]

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

  def supported_format?(:jxl), do: :jxl
  def supported_format?("JPEG"), do: :jpeg
  def supported_format?("PNG"), do: true
  def supported_format?("GIF"), do: true
  def supported_format?("WEBP"), do: true
  def supported_format?(_), do: false

  def encode(path_in, path_out, extra_args) do
    args = @cjxl_args ++ extra_args

    case System.cmd("cjxl", args ++ [path_in, path_out], stderr_to_stdout: true) do
      {output, 0} ->
        case File.stat(path_out) do
          {:ok, %{size: size}} -> {:ok, {size, path_out, args, output}}
          {:error, err} -> {:error, {:stat, err}}
        end

      err ->
        {:error, err}
    end
  end

  def best_encode(format, path_in, path_out) do
    [[path_in, path_in <> ".jxl", []]]
    |> Kernel.++(if format == :jpeg, do: [[path_in, path_in <> ".j.jxl", ["-j", "0"]]], else: [])
    |> Enum.reduce_while([], fn args, acc ->
      case apply(__MODULE__, :encode, args) do
        {:ok, resp} -> {:cont, acc ++ [resp]}
        err -> {:halt, err}
      end
    end)
    |> case do
      {:error, err} ->
        err

      results ->
        results = Enum.sort_by(results, &elem(&1, 0), :asc)

        case Enum.at(results, 0) do
          nil ->
            {:error, :nothing}

          {size, path, params, output} ->
            case File.cp(path, path_out) do
              :ok ->
                Enum.each(results, &File.rm(elem(&1, 1)))

                version = output |> String.split("\n") |> Enum.at(0)
                params = Enum.join(params, " ")
                hash = Uploader.get_hash(path_out)

                {:ok, size, version, params, hash}

              err ->
                err
            end
        end
    end
  end

  def process(:jxl, job) do
    decoded = job.path <> ".png"

    case Uploader.decode_jxl(job.path, decoded, &Uploader.get_hash/1) do
      {:ok, png_hash} ->
        # if png of jxl exists, remember jxl
        if upload = Repo.get_by(Upload, hash: png_hash) |> Repo.preload(:image) do
          create_upload(upload.image, job, :jxl)
          File.rm(job.path)
          WorkerManager.finish(EncoderManager, job)
        else
          if pixels_hash = Uploader.get_pixels_hash(decoded) do
            # if pixels of jxl exists, remember jxl
            if image = Repo.get_by(Image, pixels_hash: pixels_hash) do
              create_upload(image, job, :jxl)
              File.rm(job.path)
              WorkerManager.finish(EncoderManager, job)
            else
              size = File.stat!(job.path).size
              create_image(job, job.hash, pixels_hash, size, job.path, decoded)
            end
          end
        end

        File.rm(decoded)

      err ->
        IO.inspect(err)
    end
  end

  def process(false, job) do
    File.rm(job.path)
    WorkerManager.finish(EncoderManager, job)
  end

  def process(format, job) do
    if pixels_hash = Uploader.get_pixels_hash(job.path) do
      # if pixels of image exists, remember image
      if image = Repo.get_by(Image, pixels_hash: pixels_hash) do
        create_upload(image, job, format)
        File.rm(job.path)
        WorkerManager.finish(EncoderManager, job)
      else
        case best_encode(format, job.path, job.path <> ".f.jxl") do
          {:ok, size, version, params, hash} when not is_nil(hash) ->
            decoded = job.path <> ".f.jxl.png"

            case Uploader.decode_jxl(
                   job.path <> ".f.jxl",
                   decoded,
                   &Uploader.get_pixels_hash/1
                 ) do
              {:ok, new_pixels_hash} ->
                create_image(
                  job,
                  hash,
                  new_pixels_hash,
                  size,
                  job.path <> ".f.jxl",
                  decoded,
                  {version, params},
                  fn image ->
                    create_upload(image, job, format)
                    File.rm(job.path)
                    File.rm(decoded)
                  end
                )

              err ->
                IO.inspect(err)
            end

            File.rm(decoded)

          err ->
            IO.inspect(err)
        end
      end
    end
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
          Uploader.get_format(job.path)
          |> supported_format?()
          |> process(job)
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
        size,
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
      filesize: size,
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

  def create_upload(image, job, format) do
    %Upload{hash: job.hash, filesize: File.stat!(job.path).size, filetype: to_string(format)}
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
