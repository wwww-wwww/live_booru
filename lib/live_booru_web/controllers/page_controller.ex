defmodule LiveBooruWeb.PageController do
  use LiveBooruWeb, :controller

  def file(conn, %{"file" => file}) do
    conn
    |> put_resp_content_type("image/jxl")
    |> Plug.Conn.send_file(200, Path.join(LiveBooru.files_root(), file))
  end

  def thumb(conn, %{"file" => file}) do
    conn
    |> Plug.Conn.send_file(200, Path.join(LiveBooru.thumb_root(), file))
  end
end
