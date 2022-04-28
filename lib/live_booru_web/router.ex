defmodule LiveBooruWeb.Router do
  use LiveBooruWeb, :router

  import LiveBooruWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {LiveBooruWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", LiveBooruWeb do
    pipe_through :browser

    get "/file/:file", PageController, :file
    get "/thumb/:file", PageController, :thumb

    live "/", IndexLive
    live "/queue", QueueLive
    live "/image/:id/more", ImageMoreLive
    live "/image/:id/changes", ImageChangesLive
    live "/image/:id", ImageLive

    live "/tag/id/:id", TagLive
    live "/tag/name/:name", TagLive

    live "/tag/id/:id/changes", TagChangesLive
    live "/tag/name/:name/changes", TagChangesLive

    live "/tags", TagListLive

    scope "/" do
      pipe_through :require_authenticated_user
      live "/upload", UploadLive

      live "/image/:id/edit", ImageEditLive
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", LiveBooruWeb do
  #   pipe_through :api
  # end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: LiveBooruWeb.Telemetry
    end
  end

  ## Authentication routes

  scope "/", LiveBooruWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
    get "/users/log_in", UserSessionController, :new
    post "/users/log_in", UserSessionController, :create
  end

  scope "/", LiveBooruWeb do
    pipe_through [:browser]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
  end

  scope "/", LiveBooruWeb do
    pipe_through [:browser, :require_authenticated_user]

    delete "/users/log_out", UserSessionController, :delete
  end
end
