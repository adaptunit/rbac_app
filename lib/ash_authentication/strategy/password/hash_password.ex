defmodule AshAuthentication.Strategy.Password.HashPassword do
  @moduledoc false

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_argument(changeset, :password) do
      nil ->
        changeset

      password ->
        hashed_password = Bcrypt.hash_pwd_salt(password)
        Ash.Changeset.force_change_attribute(changeset, :hashed_password, hashed_password)
    end
  end

  @impl true
  def has_change?, do: true
end
