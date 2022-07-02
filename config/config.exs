# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :live_booru,
  ecto_repos: [LiveBooru.Repo],
  n_encoders: 2,
  autotag_url: "http://localhost:5000/evaluate",
  files_root: "/tank/booru/files",
  thumb_root: "/tank/booru/thumb"

# Configures the endpoint
config :live_booru, LiveBooruWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: LiveBooruWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: LiveBooru.PubSub,
  live_view: [signing_salt: "S+LcMGS3"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.14.29",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :dart_sass,
  version: "1.39.0",
  default: [
    args: ~w(css/app.scss ../priv/static/assets/app.css),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :mime, :types, %{
  "image/jxl" => ["jxl"]
}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
