defmodule LiveBooru.AutoTag do
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
    alpha =
      jxlinfo
      |> String.split("\n")
      |> Enum.any?(&(String.trim(&1) == "type: Alpha"))
      |> if do
        case System.cmd("python3", ["check_alpha.py", decoded]) do
          {output, 0} -> String.trim(output) == "True"
          _ -> true
        end
      else
        false
      end

    grayscale =
      jxlinfo
      |> String.split("\n")
      |> Enum.any?(&(String.trim(&1) == "num_color_channels: 1"))

    animation =
      jxlinfo
      |> String.split("\n")
      |> Enum.any?(&(String.trim(&1) == "have_animation: 1"))

    {w, h} = dimensions(jxlinfo)
    mp = w * h

    tags
    |> append_if(alpha, "Alpha Transparency")
    |> append_if(grayscale, "Grayscale")
    |> append_if(animation, "Animation")
    |> append_if(mp > 1_900_000, "High Resolution")
    |> append_if(mp > 6_000_000, "Absurd Resolution")
    |> Enum.uniq()
  end
end
