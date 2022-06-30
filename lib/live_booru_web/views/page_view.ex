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

  def tag_link(socket, tag, count, true) do
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

  def tag_link(socket, tag, count, search) do
    [a, b, c] = tag_link(socket, tag, count, true)

    assigns = %{
      elements: [
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
    }

    ~H"<%= for e <- @elements do %><%= e %><% end %>"
  end

  def tag_link(socket, tag, count) do
    assigns = %{elements: tag_link(socket, tag, count, true)}
    ~H"<%= for e <- @elements do %><%= e %><% end %>"
  end

  def score(image), do: Enum.reduce(image.votes, 0, &if(&1.upvote, do: &2 + 1, else: &2 - 1))

  def rating(image) do
    cond do
      Enum.any?(image.tags, &(&1.name == "NSFW")) -> "NSFW"
      Enum.any?(image.tags, &(&1.name == "Suggestive")) -> "Suggestive"
      true -> "Safe"
    end
  end

  def children(socket, %Tag{children: %Ecto.Association.NotLoaded{}} = root, current),
    do: children(socket, Tag.get_children(root), current)

  def children(socket, root, current) do
    e =
      if current.id == root.id do
        content_tag(:span, class: root.type) do
          root.name
        end
      else
        live_patch(root.name,
          to: Routes.live_path(socket, LiveBooruWeb.TagLive, root.id),
          class: root.type
        )
      end

    content_tag(:li) do
      elements =
        if length(root.children) > 0 do
          [
            e,
            content_tag(:ul) do
              Enum.map(
                root.children,
                &children(socket, &1, current)
              )
            end
          ]
        else
          [e]
        end

      assigns = %{elements: elements}

      ~H"<%= for e <- @elements do %><%= e %><% end %>"
    end
  end
end
