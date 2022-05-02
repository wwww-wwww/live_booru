defmodule LiveBooruWeb.PageView do
  use LiveBooruWeb, :view

  alias LiveBooru.{Repo, Comment, Image, Tag}

  def image(socket, assigns, %{id: id, thumb: thumb}) do
    live_patch(to: Routes.live_path(socket, LiveBooruWeb.ImageLive, id)) do
      case assigns[:image] do
        %{id: ^id} ->
          img_tag(Routes.static_path(socket, "/thumb/#{Path.basename(thumb)}"), class: "selected")

        _ ->
          img_tag(Routes.static_path(socket, "/thumb/#{Path.basename(thumb)}"))
      end
    end
  end

  def replace(text, re, fun) do
    Regex.scan(re, text || "")
    |> Enum.reduce(text, fun)
  end

  def format_description(_socket, nil), do: ""

  def format_description(socket, text) do
    {:ok, text, _} = Earmark.as_html(text)

    text
    |> replace(~r/%Tag{([0-9]+?)}/, fn [full, id], acc ->
      Repo.get(Tag, id)
      |> case do
        nil ->
          acc

        tag ->
          String.replace(
            acc,
            full,
            safe_to_string(
              live_patch(tag.name, to: Routes.live_path(socket, LiveBooruWeb.TagLive, id))
            )
          )
      end
    end)
    |> replace(~r/%Image{([0-9]+?)}/, fn [full, id], acc ->
      Repo.get(Image, id)
      |> case do
        nil ->
          acc

        image ->
          String.replace(
            acc,
            full,
            safe_to_string(
              live_patch(image.name, to: Routes.live_path(socket, LiveBooruWeb.ImageLive, id))
            )
          )
      end
    end)
    |> replace(~r/%Comment{([0-9]+?)}/, fn [full, id], acc ->
      Repo.get(Comment, id)
      |> case do
        nil ->
          acc

        %{id: id, image_id: image_id} ->
          String.replace(
            acc,
            full,
            safe_to_string(
              live_patch("##{id}",
                to: Routes.live_path(socket, LiveBooruWeb.ImageLive, image_id) <> "#comment_#{id}"
              )
            )
          )
      end
    end)
  end

  def quote_tag(%{name: name}) do
    if String.contains?(name, " ") do
      "\"#{name}\""
    else
      name
    end
  end

  def tag_link(socket, tag, count, search) do
    [a, b, c] = tag_link(socket, tag, count)

    [
      a,
      live_patch("+",
        to:
          Routes.live_path(socket, LiveBooruWeb.IndexLive,
            q: String.trim("#{search} #{quote_tag(tag)}")
          )
      ),
      live_patch("-",
        to:
          Routes.live_path(socket, LiveBooruWeb.IndexLive,
            q: String.trim("#{search} -#{quote_tag(tag)}")
          )
      ),
      b,
      c
    ]
  end

  def tag_link(socket, tag, count) do
    [
      live_patch("?", to: Routes.live_path(socket, LiveBooruWeb.TagLive, tag.id)),
      live_patch(tag.name,
        to: Routes.live_path(socket, LiveBooruWeb.IndexLive, q: quote_tag(tag))
      ),
      content_tag(:span, class: "count") do
        count
      end
    ]
  end
end
