defmodule Quantum.Accounts.Encryption do
  alias Quantum.Accounts.User

  def hash_password(password), do: Bcrypt.hash_pwd_salt(password)

  def validate_password(%User{} = user, password), do: Bcrypt.check_pass(user, password)
end
