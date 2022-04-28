defmodule LiveBooru.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      LiveBooru.Repo,
      # Start the Telemetry supervisor
      LiveBooruWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: LiveBooru.PubSub},
      # Start the Endpoint (http/https)
      LiveBooruWeb.Endpoint,
      Supervisor.child_spec(
        {LiveBooru.WorkerManager, name: LiveBooru.EncoderManager, queue: LiveBooru.EncodeJob},
        id: LiveBooru.EncoderManager
      )
    ]

    encoders =
      1..Application.fetch_env!(:live_booru, :n_encoders)
      |> Enum.map(
        &Supervisor.child_spec({LiveBooru.Encoder, id: &1}, id: "LiveBooru.Encoder#{&1}")
      )

    children = children ++ encoders
    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: LiveBooru.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    LiveBooruWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
