defmodule LiveBooruWeb.TagLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.{Repo, Tag}

  import Ecto.Query, only: [from: 2]

  def render(assigns) do
    LiveBooruWeb.PageView.render("tag.html", assigns)
  end

  def mount(%Tag{} = tag, _session, socket) do
    tag
    |> Repo.preload([:aliases, :tag, :children, :parent])
    |> case do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Tag does not exist")
         |> push_redirect(to: "/")}

      tag ->
        count =
          Repo.count_tags([tag])
          |> Enum.at(0)
          |> elem(1)

        root = Tag.root(tag)

        socket =
          socket
          |> assign(
            :can_edit,
            LiveBooru.Accounts.admin?(socket.assigns.current_user) or
              (not tag.locked and !is_nil(socket.assigns.current_user))
          )
          |> assign(:edit_level, LiveBooru.Accounts.level(socket.assigns.current_user))
          |> assign(:editing, false)
          |> assign(:tag, tag)
          |> assign(:count, count)
          |> assign(:root, root)
          |> assign(:tag_suggestions, [])

        {:ok, socket}
    end
  end

  def mount(%{"name" => name}, session, socket) do
    mount(Repo.get_by(Tag, name: name), session, socket)
  end

  def mount(%{"id" => id}, session, socket) do
    mount(Repo.get(Tag, id), session, socket)
  end

  def handle_params(%{"id" => id}, session, socket) do
    {:ok, socket} = mount(Repo.get(Tag, id), session, socket)
    {:noreply, socket}
  end

  def handle_params(%{"name" => name}, session, socket) do
    {:ok, socket} = mount(Repo.get_by(Tag, name: name), session, socket)
    {:noreply, socket}
  end

  def change_tag(socket, attrs, admin \\ true) do
    if (!is_nil(socket.assigns.current_user) and not admin) or
         LiveBooru.Accounts.admin?(socket.assigns.current_user) do
      case Repo.get(Tag, socket.assigns.tag.id) do
        nil ->
          socket
          |> put_flash(:error, "Tag does not exist")
          |> push_redirect(to: "/")

        tag ->
          case Ecto.Changeset.change(tag, attrs) do
            %{changes: changes} when map_size(changes) == 0 ->
              socket
              |> assign(:editing, false)
              |> put_flash(:info, "No changes made")

            change ->
              case Repo.update(change) do
                {:ok, new_tag} ->
                  if attrs[:description] do
                    %LiveBooru.TagChange{
                      user_id: socket.assigns.current_user.id,
                      tag_id: tag.id,
                      description: attrs[:description],
                      description_prev: tag.description
                    }
                    |> Repo.insert()
                  end

                  if attrs[:tag_id] do
                    LiveBooru.aliases()
                  end

                  socket
                  |> assign(:tag, Repo.preload(new_tag, [:tag, :aliases, :children, :parent]))
                  |> assign(:editing, false)

                {:error, cs} ->
                  socket |> put_flash(:error, inspect(cs))
              end
          end
      end
    else
      put_flash(socket, :error, "Not allowed")
    end
  end

  def handle_event("edit", _, socket) do
    socket = assign(socket, :editing, true)
    {:noreply, socket}
  end

  def handle_event("lock", _, socket) do
    socket = change_tag(socket, %{locked: true})

    {:noreply, socket}
  end

  def handle_event("unlock", _, socket) do
    socket = change_tag(socket, %{locked: false})

    {:noreply, socket}
  end

  def handle_event("save", %{"name" => name}, socket) do
    socket = change_tag(socket, %{name: name})

    {:noreply, socket}
  end

  def handle_event("save", %{"type" => type}, socket) do
    socket = change_tag(socket, %{type: String.to_atom(type)})

    {:noreply, socket}
  end

  def handle_event("save", %{"description" => description}, socket) do
    socket = change_tag(socket, %{description: description}, false)

    {:noreply, socket}
  end

  def handle_event("save", %{"tag" => tag_name}, socket) do
    socket =
      case String.trim(tag_name) do
        "" ->
          change_tag(socket, %{tag_id: nil})

        tag_name ->
          Repo.get_by(Tag, name: tag_name)
          |> case do
            nil ->
              put_flash(socket, :error, "Tag does not exist")

            tag ->
              change_tag(socket, %{tag_id: tag.id})
          end
      end

    {:noreply, socket}
  end

  def handle_event("save", %{"parent" => tag_name}, socket) do
    socket =
      case String.trim(tag_name) do
        "" ->
          change_tag(socket, %{parent_id: nil})

        tag_name ->
          Repo.get_by(Tag, name: tag_name)
          |> case do
            nil ->
              put_flash(socket, :error, "Tag does not exist")

            tag ->
              if not Enum.any?(
                   Tag.descendants(socket.assigns.tag) |> Repo.all(),
                   &(&1.id == tag.id)
                 ) do
                change_tag(socket, %{parent_id: tag.id})
              else
                put_flash(socket, :error, "Parent forms a cycle")
              end
          end
      end

    {:noreply, socket}
  end

  def handle_event("cancel", _, socket) do
    socket = assign(socket, :editing, false)

    {:noreply, socket}
  end

  def handle_event("suggest_tags", %{"parent" => q}, socket) do
    handle_event("suggest_tags", %{"tag" => q}, socket)
  end

  def handle_event("suggest_tags", %{"tag" => q}, socket) do
    socket =
      if String.length(q) > 0 do
        query =
          from t in Repo.build_search_tags(q),
            where: t.type != :meta_system

        suggestions =
          Repo.all(query)
          |> Enum.map(& &1.name)
          |> Enum.sort()

        assign(socket, :tag_suggestions, suggestions)
      else
        socket
      end

    {:noreply, socket}
  end
end

defmodule LiveBooruWeb.TagChangesLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.{Repo, Tag}

  def render(assigns) do
    LiveBooruWeb.PageView.render("tag_changes.html", assigns)
  end

  def mount(%Tag{} = tag, _session, socket) do
    tag
    |> Repo.preload(changes: [:user])
    |> case do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Tag does not exist")
         |> push_redirect(to: "/")}

      tag ->
        socket =
          socket
          |> assign(:tag, tag)

        {:ok, socket}
    end
  end

  def mount(%{"name" => name}, session, socket) do
    mount(Repo.get_by(Tag, name: name), session, socket)
  end

  def mount(%{"id" => id}, session, socket) do
    mount(Repo.get(Tag, id), session, socket)
  end

  def handle_params(%{"id" => id}, session, socket) do
    {:ok, socket} = mount(Repo.get(Tag, id), session, socket)
    {:noreply, socket}
  end

  def handle_params(%{"name" => name}, session, socket) do
    {:ok, socket} = mount(Repo.get_by(Tag, name: name), session, socket)
    {:noreply, socket}
  end
end
