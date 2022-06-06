defmodule LiveBooru.Uploader do
  alias LiveBooru.{Repo, Image, Upload, EncodeJob}

  def get_hash(path) do
    if File.exists?(path) do
      File.stream!(path, [], 2048)
      |> Enum.reduce(:crypto.hash_init(:md5), fn line, acc -> :crypto.hash_update(acc, line) end)
      |> :crypto.hash_final()
      |> Base.encode16()
      |> String.downcase()
    else
      nil
    end
  end

  def get_pixels_hash(path) do
    case System.cmd("python3", ["hash_pixels.py", path]) do
      {output, 0} -> String.trim(output)
      _err -> nil
    end
  end

  def decode_jxl(in_path, out_path, fun) do
    case System.cmd("djxl", [in_path, out_path], stderr_to_stdout: true) do
      {output, 0} ->
        if File.exists?(out_path) do
          {:ok, fun.(out_path)}
        else
          output
        end

      err ->
        err
    end
  end

  def exists?(hash) do
    Repo.get_by(Image, hash: hash) != nil or
      Repo.get_by(Upload, hash: hash) != nil
  end

  def job_exists?(hash), do: Repo.get_by(EncodeJob, hash: hash) != nil

  def get_format(path) do
    if LiveBooru.Jxl.path_is_jxl?(path) do
      :jxl
    else
      case System.cmd("python3", ["format.py", path]) do
        {output, 0} -> String.trim(output)
        _err -> nil
      end
    end
  end
end
