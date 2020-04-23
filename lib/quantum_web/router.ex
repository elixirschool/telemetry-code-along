defmodule QuantumWeb.Router do
  use QuantumWeb, :router
  import Phoenix.LiveDashboard.Router
  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug QuantumWeb.Plugs.CurrentUser
    plug Plug.Telemetry, event_prefix: [:browser, :request]
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  if Mix.env() == :dev do
    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: Quantum.Telemetry
    end
  end

  scope "/", QuantumWeb do
    pipe_through [:browser]
    get "/", PageController, :index
  end

  scope "/", QuantumWeb do
    pipe_through [:browser, QuantumWeb.Plugs.Guest]

    resources "/register", UserController, only: [:create, :new]
    get "/login", SessionController, :new
    post "/login", SessionController, :create
  end

  scope "/", QuantumWeb do
    pipe_through [:browser, QuantumWeb.Plugs.Auth]

    delete "/logout", SessionController, :delete

    get "/users/:id", UserController, :show
    live "/buttons", ButtonLive
  end

  # if Mix.env() == :dev do
  #   scope "/" do
  #     pipe_through :browser
  #     live_dashboard "/dashboard"
  #   end
  # end

  # Other scopes may use custom stacks.
  # scope "/api", QuantumWeb do
  #   pipe_through :api
  # end
end
