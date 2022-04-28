defmodule LiveBooruWeb.PageView do
  use LiveBooruWeb, :view

  alias LiveBooru.{Repo, Tag}

  import Ecto.Query, only: [from: 2]

  def image(socket, assigns, %{id: id, thumb: thumb}) do
    live_patch(to: Routes.live_path(socket, LiveBooruWeb.ImageLive, id)) do
      case assigns[:image] do
        %{id: ^id} ->
          img_tag(Routes.page_path(socket, :thumb, Path.basename(thumb)), class: "selected")

        _ ->
          img_tag(Routes.page_path(socket, :thumb, Path.basename(thumb)))
      end
    end
  end

  def format_description(socket, text) do
    Regex.scan(~r/%Tag{([0-9]+?)}/, text || "")
    |> Enum.reduce(text, fn [full, id], acc ->
      Repo.get(Tag, id)
      |> case do
        nil ->
          acc

        tag ->
          String.replace(
            text,
            full,
            safe_to_string(
              live_patch(tag.name, to: Routes.live_path(socket, LiveBooruWeb.TagLive, id))
            )
          )
      end
    end)
  end

  def tag_link(socket, tag, search) do
    [a, b, c] = tag_link(socket, tag)

    [
      a,
      live_patch("+",
        to:
          Routes.live_path(socket, LiveBooruWeb.IndexLive,
            q: String.trim("#{search} \"#{tag.name}\"")
          )
      ),
      live_patch("-",
        to:
          Routes.live_path(socket, LiveBooruWeb.IndexLive,
            q: String.trim("#{search} -\"#{tag.name}\"")
          )
      ),
      b,
      c
    ]
  end

  def tag_link(socket, tag) do
    query = from t in LiveBooru.ImagesTags, where: t.tag_id == ^tag.id
    count = Repo.aggregate(query, :count)

    [
      live_patch("?", to: Routes.live_path(socket, LiveBooruWeb.TagLive, tag.id)),
      live_patch(tag.name,
        to: Routes.live_path(socket, LiveBooruWeb.IndexLive, q: "\"#{tag.name}\"")
      ),
      content_tag(:span) do
        count
      end
    ]
  end
end
