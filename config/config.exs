# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :quantum,
  ecto_repos: [Quantum.Repo]

# Configures the endpoint
config :quantum, QuantumWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "kP2NY4oqKaAig+gvBoL7L6DLBCmSQs2uv23s32X7Z8fZ2hdYo3KETNd6/bqeW9E/",
  render_errors: [view: QuantumWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Quantum.PubSub, adapter: Phoenix.PubSub.PG2],
  live_view: [signing_salt: "84Az6Ix0"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# config :my_app, QuantumWeb.Endpoint,
#    live_view: [signing_salt: "SECRET_SALT"]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
