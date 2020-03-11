defmodule QuantumWeb.PageController do
  use QuantumWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
