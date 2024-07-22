defmodule LiveNxIREEWeb.HomeLive do
  use LiveNxIREEWeb, :live_view
  use LiveNxIREENative, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Contexts")
    |> assign(:home, nil)
  end
end
