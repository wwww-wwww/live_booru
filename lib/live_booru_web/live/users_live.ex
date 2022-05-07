defmodule LiveBooruWeb.UsersLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.Accounts.User
  alias LiveBooru.Repo

  import Ecto.Query, only: [from: 2]

  def render(assigns) do
    LiveBooruWeb.PageView.render("users.html", assigns)
  end

  def mount(_params, _session, socket) do
    users = Repo.all(User) |> Enum.sort_by(& &1.id)
    {:ok, assign(socket, :users, users)}
  end

  def handle_params(_params, _session, socket) do
    {:noreply, socket}
  end
end
