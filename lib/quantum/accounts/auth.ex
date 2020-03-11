defmodule Quantum.Accounts.Auth do
  alias Quantum.Accounts.{Encryption, User}

  def login(params, repo) do
    user = repo.get_by(User, email: String.downcase(params["email"]))

    case authenticate(user, params["password"]) do
      true -> {:ok, user}
      _ -> :error
    end
  end

  defp authenticate(user, password) do
    if user do
      case Encryption.validate_password(user, password) do
        {:ok, validated_user} -> validated_user.email == user.email
        {:error, _} -> false
      end
    else
      nil
    end
  end

  def signed_in?(conn) do
    conn.assigns[:current_user]
  end
end
