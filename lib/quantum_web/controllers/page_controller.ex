defmodule QuantumWeb.PageController do
  use QuantumWeb, :controller

  def index(conn, _params) do
    conn
    |> put_status(500)
    |> put_view(HelloWeb.ErrorView)
    |> render("500.html")
    # render(conn, "index.html")
  end
end
