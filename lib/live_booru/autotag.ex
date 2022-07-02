defmodule LiveBooru.AutoTag do
  alias LiveBooru.{Repo, Tag}

  import Ecto.Query, only: [from: 2]

  @re_dimensions ~r/^JPEG XL .+?, ([0-9]+?)x([0-9]+?),/m

  def dimensions(jxlinfo) do
    Regex.run(@re_dimensions, jxlinfo)
    |> case do
      [_, x, y] -> {Integer.parse(x) |> elem(0), Integer.parse(y) |> elem(0)}
      _ -> {0, 0}
    end
  end

  defp append_if(list, condition, item) do
    if condition, do: list ++ [item], else: list
  end

  def tag(tags, jxlinfo, _job, decoded) do
    jxlinfo_lines =
      jxlinfo
      |> String.split("\n")
      |> Enum.map(&String.trim(&1))

    alpha =
      jxlinfo_lines
      |> Enum.any?(&(&1 == "type: Alpha"))
      |> if do
        if !is_nil(decoded) do
          case System.cmd("python3", ["check_alpha.py", decoded]) do
            {output, 0} -> String.trim(output) == "True"
            _ -> true
          end
        else
          false
        end
      else
        false
      end

    grayscale =
      jxlinfo_lines
      |> Enum.any?(&(&1 == "num_color_channels: 1"))

    animation =
      jxlinfo_lines
      |> Enum.any?(&(&1 == "have_animation: 1"))

    jpeg_reconstruction =
      jxlinfo_lines
      |> Enum.any?(&(&1 == "JPEG bitstream reconstruction data available"))

    {w, h} = dimensions(jxlinfo)
    mp = w * h

    tags
    |> append_if(mp > 1_900_000, "High Resolution")
    |> append_if(mp > 6_000_000, "Absurd Resolution")
    |> append_if(alpha, "Alpha Transparency")
    |> append_if(animation, "Animated")
    |> append_if(grayscale, "Grayscale")
    |> append_if(jpeg_reconstruction, "JPEG Reconstruction")
    |> Enum.uniq()
  end

  def autotag_url(), do: Application.fetch_env!(:live_booru, :autotag_url)

  def autotag_req(path) do
    HTTPoison.post(
      autotag_url(),
      {:multipart, [{:file, path}, {"format", "json"}]}
    )
  end

  def autotag(path), do: autotag(path, autotag_url())

  def autotag(path, autotag_url) when is_bitstring(autotag_url) and bit_size(autotag_url) > 0 do
    if LiveBooru.Jxl.path_is_jxl?(path) do
      LiveBooru.Uploader.decode_jxl(path, path <> ".png", &autotag_req/1)
      |> case do
        {:ok, res} ->
          File.rm(path <> ".png")
          res

        err ->
          err
      end
    else
      autotag_req(path)
    end
    |> case do
      {:ok, %{body: body, status_code: 200}} ->
        tags =
          Jason.decode!(body)
          |> Enum.at(0)
          |> Map.get("tags")
          |> Enum.sort_by(&elem(&1, 1), &>=/2)
          |> Enum.filter(&(not String.contains?(elem(&1, 0), ":")))

        tag_names =
          tags
          |> Enum.map(&[&1, {String.replace(elem(&1, 0), "_", " "), elem(&1, 1)}])
          |> List.flatten()
          |> Enum.uniq_by(&elem(&1, 0))
          |> Enum.map(&elem(&1, 0))

        tag_map =
          from(t in Tag, where: fragment("lower(?)", t.name) in ^tag_names)
          |> Repo.all()
          |> Repo.preload(:tag)
          |> Enum.map(&{String.downcase(&1.name), &1.tag || &1})
          |> Map.new()

        Enum.map(tags, fn {tag, conf} ->
          tag = Map.get(tag_map, tag) || Map.get(tag_map, String.replace(tag, "_", " ")) || tag

          tag_name =
            case tag do
              %Tag{type: :meta_system} -> nil
              %Tag{name: name, type: type} -> {name, type}
              _ -> {tag, :default}
            end

          {tag_name, conf}
        end)
        |> Enum.filter(&(not is_nil(elem(&1, 0))))

      _ ->
        []
    end
  end

  def autotag(_path, _), do: []
end
