defmodule LiveBooru.Jxl do
  @container <<0, 0, 0, 0xC, 74, 88, 76, 32, 0xD, 0xA, 0x87, 0xA>>
  @codestream <<0xFF, 0x0A>>

  def is_jxl?(data) do
    case data do
      @container <> _ = ^data -> true
      @codestream <> _ = ^data -> true
      _ -> false
    end
  end

  def path_is_jxl?(path) do
    File.stream!(path, [], 12)
    |> Enum.take(1)
    |> Enum.at(0)
    |> is_jxl?()
  end

  def info(path) do
    case System.cmd("jxlinfo", ["-v", path]) do
      {output, 0} -> output
      _ -> nil
    end
  end
end
