defmodule LiveBooruWeb.LayoutView do
  use LiveBooruWeb, :view

  # Phoenix LiveDashboard is available only in development by default,
  # so we instruct Elixir to not warn if the dashboard route is missing.
  @compile {:no_warn_undefined, {Routes, :live_dashboard_path, 2}}

  def nav_link(_, _, _, _ \\ [])

  def nav_link(%{view: view} = socket, name, module, opts) do
    live_redirect(name,
      to: Routes.live_path(socket, module, opts),
      class:
        if(view == module,
          do: "selected",
          else: ""
        )
    )
  end

  def nav_link(conn, name, module, opts) do
    live_redirect(name, to: Routes.live_path(conn, module, opts))
  end
end
