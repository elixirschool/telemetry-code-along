defmodule QuantumWeb.Plugs.Guest do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    if Plug.Conn.get_session(conn, :current_user_id) do
      conn
      |> redirect(to: QuantumWeb.Router.Helpers.page_path(conn, :index))
      |> halt()
    end
    conn
  end
end
