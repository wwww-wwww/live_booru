defmodule LiveBooruWeb.UploadLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.{EncodeJob, Repo, Uploader}

  import Ecto.Query, only: [from: 2]

  def render(assigns) do
    LiveBooruWeb.PageView.render("upload.html", assigns)
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:title, "")
      |> assign(:source, "")
      |> assign(:rating, "nsfw")
      |> assign(:uploaded_files, [])
      |> assign(:suggestions, [])
      |> assign(:tags, MapSet.new())
      |> allow_upload(:file,
        accept: ~w(.jxl .jpg .jpeg .png .webp .gif),
        max_entries: 1,
        max_file_size: 50_000_000
      )

    {:ok, socket}
  end

  def handle_params(_params, _session, socket) do
    {:noreply, socket}
  end

  def handle_event("tag_remove", %{"value" => tag_id}, socket) do
    socket =
      socket
      |> assign(:tags, MapSet.delete(socket.assigns.tags, tag_id))

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

    if String.length(value) > 0 do
      suggestions =
        from(t in Repo.build_search_tags(value),
          where: t.type != :meta_system,
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

  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :file, ref)}
  end

  def handle_event("validate", %{"_target" => ["title"], "title" => title}, socket) do
    {:noreply, assign(socket, :title, title)}
  end

  def handle_event("validate", %{"_target" => ["source"], "source" => source}, socket) do
    {:noreply, assign(socket, :source, source)}
  end

  def handle_event("validate", %{"_target" => ["rating"], "rating" => rating}, socket) do
    {:noreply, assign(socket, :rating, rating)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("submit", %{"rating" => rating, "source" => source, "title" => title}, socket) do
    rating_tag =
      case rating do
        "safe" -> []
        "suggestive" -> ["Suggestive"]
        _ -> ["NSFW"]
      end

    consume_uploaded_entries(socket, :file, fn %{path: path}, _entry ->
      hash = Uploader.get_hash(path)

      if Uploader.exists?(hash) or Uploader.job_exists?(hash) do
        {:ok, "File already exists"}
      else
        File.cp(path, "tmp/#{hash}")
        |> case do
          :ok ->
            %EncodeJob{
              hash: hash,
              tags: MapSet.to_list(socket.assigns.tags) ++ rating_tag,
              source: source,
              title: title,
              is_jxl: LiveBooru.Jxl.path_is_jxl?(path)
            }
            |> Ecto.Changeset.change()
            |> Ecto.Changeset.put_assoc(:user, socket.assigns.current_user)
            |> Repo.insert()
            |> case do
              {:ok, _job} ->
                LiveBooruWeb.QueueLive.update()
                LiveBooru.Encoder.notify()
                {:ok, :ok}

              {:error, cs} ->
                {:ok, cs}
            end

          err ->
            {:ok, err}
        end
      end
    end)
    |> case do
      [:ok] -> {:noreply, put_flash(socket, :info, "Successfully submitted")}
      [err] -> {:noreply, put_flash(socket, :error, inspect(err))}
      [] -> {:noreply, socket}
    end
  end
end
