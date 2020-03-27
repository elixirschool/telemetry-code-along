defmodule QuantumWeb.ButtonLive do
  use Phoenix.LiveView, layout: {QuantumWeb.LayoutView, "live.html"}
  alias Quantum.Accounts

  def mount(_params, %{"current_user_id" => user_id}, socket) do
    socket =
      socket
      |> assign(:current_user, Accounts.get_user!(user_id))
      |> assign(:selected_button, nil)
    {:ok, socket}
  end

  def render(assigns) do
    Phoenix.View.render(QuantumWeb.ButtonView, "show.html", assigns)
  end

  def handle_event("button_click", %{"button" => btn}, socket) do
    socket =
      socket
      |> assign(:selected_button, btn)

    {:noreply, socket}
  end
end
