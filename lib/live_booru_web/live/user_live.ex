defmodule LiveBooruWeb.SignInLive do
  use LiveBooruWeb, :live_view

  def render(assigns) do
    LiveBooruWeb.UserView.render("sign_in.html", assigns)
  end

  def mount(_, _, socket) do
    {:ok, socket}
  end
end

defmodule LiveBooruWeb.SignUpLive do
  use LiveBooruWeb, :live_view

  alias LiveBooru.Accounts
  alias LiveBooru.Accounts.User

  def render(assigns) do
    LiveBooruWeb.UserView.render("sign_up.html", assigns)
  end

  def mount(_, _, socket) do
    changeset = Accounts.change_user_registration(%User{})

    socket = assign(socket, changeset: changeset)
    {:ok, socket}
  end
end
