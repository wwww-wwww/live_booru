defmodule LiveBooruWeb.ImageEditLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.{Repo, Tag, Image}

  import Ecto.Query, only: [from: 2]

  def render(assigns) do
    LiveBooruWeb.PageView.render("image_edit.html", assigns)
  end

  def mount(%{"id" => id}, _session, socket) do
    case Repo.get(Image, id) |> Repo.preload(:tags) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Image does not exist")
         |> push_redirect(to: "/")}

      image ->
        tag_names = image.tags |> Enum.map(& &1.name)

        rating =
          cond do
            "NSFW" in tag_names -> "nsfw"
            "Suggestive" in tag_names -> "suggestive"
            true -> "safe"
          end

        socket =
          socket
          |> assign(:image, image)
          |> assign(:suggestions, [])
          |> assign(:source, image.source)
          |> assign(:rating, rating)
          |> assign(
            :tags,
            MapSet.new(
              image.tags
              |> Enum.map(& &1.name)
              |> Kernel.--(["Suggestive", "NSFW"])
            )
          )

        {:ok, socket}
    end
  end

  def handle_params(%{"id" => id}, session, socket) do
    {:ok, socket} = mount(%{"id" => id}, session, socket)
    {:noreply, socket}
  end

  def handle_event("tag_remove", %{"value" => id}, socket) do
    socket = assign(socket, :tags, MapSet.delete(socket.assigns.tags, id))
    {:noreply, socket}
  end

  def handle_event("tag_add", %{"value" => tag_id}, socket) do
    tag_id = String.trim(tag_id)

    socket =
      if String.length(tag_id) > 0 do
        tags = MapSet.put(socket.assigns.tags, tag_id)

        socket
        |> assign(:tags, tags)
        |> assign(:suggestions, socket.assigns.suggestions -- MapSet.to_list(tags))
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("tag_q", %{"value" => value}, socket) do
    value = String.trim(value)

    omit =
      if LiveBooru.Accounts.admin?(socket.assigns.current_user) do
        []
      else
        [:meta_system]
      end

    if String.length(value) > 0 do
      suggestions =
        from(t in Repo.build_search_tags(value),
          where: t.type not in ^omit,
          order_by: t.name,
          limit: 20,
          select: t.name
        )
        |> Repo.all()
        |> Kernel.--(MapSet.to_list(socket.assigns.tags))

      {:noreply, assign(socket, :suggestions, suggestions)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("validate", %{"_target" => ["source"], "source" => source}, socket) do
    {:noreply, assign(socket, :source, source)}
  end

  def handle_event("validate", %{"_target" => ["rating"], "rating" => rating}, socket) do
    {:noreply, assign(socket, :rating, rating)}
  end

  def handle_event("save", %{"rating" => rating, "source" => source}, socket) do
    socket =
      Repo.get(Image, socket.assigns.image.id)
      |> Repo.preload(:tags)
      |> case do
        nil ->
          put_flash(socket, :error, "Error finding image")

        image ->
          rating_tag =
            case rating do
              "safe" -> []
              "suggestive" -> ["Suggestive"]
              _ -> ["NSFW"]
            end

          new_tags =
            MapSet.to_list(socket.assigns.tags)
            |> Kernel.++(rating_tag)
            |> Enum.sort()

          current_tags = image.tags |> Enum.map(& &1.name) |> Enum.sort()

          if current_tags == new_tags and source == image.source do
            put_flash(socket, :info, "No changes made")
          else
            new_tags =
              Enum.map(new_tags, fn tag_name ->
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
              |> Enum.map(&Tag.parents(&1))
              |> List.flatten()
              |> Enum.uniq_by(& &1.id)
              |> Enum.sort_by(& &1.name)

            old_tags_ids = Enum.map(image.tags, & &1.id)
            new_tags_ids = Enum.map(new_tags, & &1.id)
            tags_added = new_tags_ids -- old_tags_ids
            tags_removed = old_tags_ids -- new_tags_ids

            Ecto.Changeset.change(image, %{source: source})
            |> Ecto.Changeset.put_assoc(:tags, new_tags)
            |> Repo.update()
            |> case do
              {:ok, new_image} ->
                %LiveBooru.ImageChange{
                  user_id: socket.assigns.current_user.id,
                  image_id: image.id,
                  source: source,
                  source_prev: image.source,
                  tags: Enum.map(new_tags, & &1.id) |> Enum.sort(),
                  tags_added: tags_added,
                  tags_removed: tags_removed
                }
                |> Repo.insert()

                tag_names = new_image.tags |> Enum.map(& &1.name)

                rating =
                  cond do
                    "NSFW" in tag_names -> "nsfw"
                    "Suggestive" in tag_names -> "suggestive"
                    true -> "safe"
                  end

                socket
                |> assign(:image, new_image)
                |> assign(:source, image.source)
                |> assign(:rating, rating)
                |> assign(
                  :tags,
                  MapSet.new(
                    new_image.tags
                    |> Enum.map(& &1.name)
                    |> Kernel.--(["Suggestive", "NSFW"])
                  )
                )
                |> put_flash(:info, "Image updated")

              {:error, cs} ->
                put_flash(socket, :error, inspect(cs))
            end
          end
      end

    {:noreply, socket}
  end
end
