defmodule Quantum.Repo do
  use Ecto.Repo,
    otp_app: :quantum,
    adapter: Ecto.Adapters.Postgres
end
