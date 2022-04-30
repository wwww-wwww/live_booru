defmodule LiveBooruWeb.UserRegistrationController do
  use LiveBooruWeb, :controller

  alias LiveBooru.Accounts
  alias LiveBooruWeb.UserAuth

  def create(conn, %{"user" => user_params}) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "User created successfully.")
        |> UserAuth.log_in_user(user)

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_flash(:username_error, Keyword.get(changeset.errors, :username, nil))
        |> put_flash(:password_error, Keyword.get(changeset.errors, :password, nil))
        |> redirect(to: Routes.live_path(conn, LiveBooruWeb.SignUpLive))
    end
  end
end
