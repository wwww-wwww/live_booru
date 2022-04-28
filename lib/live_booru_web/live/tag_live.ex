defmodule LiveBooruWeb.TagLive do
  use LiveBooruWeb, :live_view
  on_mount LiveBooru.Accounts

  alias LiveBooru.{Repo, Tag}

  def render(assigns) do
    LiveBooruWeb.PageView.render("tag.html", assigns)
  end

  def mount(%Tag{} = tag, _session, socket) do
    case tag do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Tag does not exist")
         |> push_redirect(to: "/")}

      tag ->
        socket =
          socket
          |> assign(
            :can_edit,
            LiveBooru.Accounts.admin?(socket.assigns.current_user) or
              (not tag.locked and !is_nil(socket.assigns.current_user))
          )
          |> assign(:editing, false)
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

  def handle_event("edit", _, socket) do
    socket = assign(socket, :editing, true)
    {:noreply, socket}
  end

  def change_tag(socket, attrs, check) do
    case Repo.get(Tag, socket.assigns.tag.id) do
      nil ->
        socket
        |> put_flash(:error, "Tag does not exist")
        |> push_redirect(to: "/")

      tag ->
        if check.() do
          case Ecto.Changeset.change(tag, attrs) do
            %{changes: changes} when map_size(changes) == 0 ->
              socket
              |> assign(:editing, false)
              |> put_flash(:info, "No changes made")

            change ->
              case Repo.update(change) do
                {:ok, tag} ->
                  if attrs[:description] do
                    %LiveBooru.TagChange{
                      user_id: socket.assigns.current_user.id,
                      tag_id: tag.id,
                      description: attrs[:description]
                    }
                    |> Repo.insert()
                  end

                  socket
                  |> assign(:tag, tag)
                  |> assign(:editing, false)

                {:error, cs} ->
                  socket |> put_flash(:error, inspect(cs))
              end
          end
        else
          put_flash(socket, :error, "Not allowed")
        end
    end
  end

  def handle_event("lock", _, socket) do
    socket =
      change_tag(socket, %{locked: true}, fn ->
        LiveBooru.Accounts.admin?(socket.assigns.current_user)
      end)

    {:noreply, socket}
  end

  def handle_event("unlock", _, socket) do
    socket =
      change_tag(socket, %{locked: false}, fn ->
        LiveBooru.Accounts.admin?(socket.assigns.current_user)
      end)

    {:noreply, socket}
  end

  def handle_event("save", %{"name" => name}, socket) do
    socket =
      change_tag(socket, %{name: name}, fn ->
        LiveBooru.Accounts.admin?(socket.assigns.current_user)
      end)

    {:noreply, socket}
  end

  def handle_event("save", %{"type" => type}, socket) do
    socket =
      change_tag(socket, %{type: String.to_atom(type)}, fn ->
        LiveBooru.Accounts.admin?(socket.assigns.current_user)
      end)

    {:noreply, socket}
  end

  def handle_event("save", %{"description" => description}, socket) do
    socket = change_tag(socket, %{description: description}, fn -> true end)

    {:noreply, socket}
  end

  def handle_event("cancel", _, socket) do
    socket = assign(socket, :editing, false)

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
