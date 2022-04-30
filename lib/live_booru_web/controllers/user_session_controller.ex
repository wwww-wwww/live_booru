defmodule LiveBooruWeb.UserSessionController do
  use LiveBooruWeb, :controller

  alias LiveBooru.Accounts
  alias LiveBooruWeb.UserAuth

  def create(conn, %{"user" => user_params}) do
    %{"username" => username, "password" => password} = user_params

    if user = Accounts.get_user_by_username_and_password(username, password) do
      UserAuth.log_in_user(conn, user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the username is registered.
      conn
      |> put_flash(:error, "Invalid username or password.")
      |> redirect(to: Routes.live_path(conn, LiveBooruWeb.SignInLive))
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
