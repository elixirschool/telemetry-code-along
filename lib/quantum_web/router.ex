defmodule QuantumWeb.Router do
  use QuantumWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug QuantumWeb.Plugs.CurrentUser
  end

  pipeline :api do
    plug :accepts, ["json"]
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
  end

  # Other scopes may use custom stacks.
  # scope "/api", QuantumWeb do
  #   pipe_through :api
  # end
end
