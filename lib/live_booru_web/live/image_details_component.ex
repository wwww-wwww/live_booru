defmodule LiveBooruWeb.ImageDetailsComponent do
  use LiveBooruWeb, :live_component

  def render(assigns) do
    LiveBooruWeb.ComponentView.render("image_details.html", assigns)
  end
end
