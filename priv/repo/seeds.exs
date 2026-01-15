# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     RbacApp.Repo.insert!(%RbacApp.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias RbacApp.Accounts.User
alias RbacApp.RBAC.{Role, UserRole}

import Ash.Query

defmodule RbacApp.Seeds do
  def run do
    roles = %{
      admin: %{
        role_name: "administrator",
        description: "Superuser with access to all resources.",
        permissions: %{
          "accounts.user" => ["*"],
          "accounts.person" => ["*"],
          "rbac.role" => ["*"],
          "rbac.user_role" => ["*"]
        }
      },
      manager: %{
        role_name: "manager",
        description: "Manager with access to affiliated users and their resources.",
        permissions: %{
          "accounts.user" => ["read"],
          "accounts.person" => ["read", "update"]
        }
      },
      basic: %{
        role_name: "basic",
        description: "Standard user with access only to their own resources.",
        permissions: %{}
      }
    }

    role_records =
      roles
      |> Enum.map(fn {key, attrs} -> {key, upsert_role(attrs)} end)
      |> Enum.into(%{})

    users = [
      %{email: "admin@example.com", password: "admin1234!", role: :admin},
      %{email: "manager@example.com", password: "manager1234!", role: :manager},
      %{email: "user@example.com", password: "user1234!", role: :basic}
    ]

    Enum.each(users, fn user_attrs ->
      user = upsert_user(user_attrs)
      role = Map.fetch!(role_records, user_attrs.role)
      ensure_user_role(user, role)
    end)
  end

  defp upsert_role(attrs) do
    Role
    |> filter(role_name == ^attrs.role_name)
    |> Ash.read_one(domain: RbacApp.RBAC, authorize?: false)
    |> case do
      {:ok, nil} ->
        changeset = Ash.Changeset.for_create(Role, :create, attrs)
        Ash.create!(changeset, domain: RbacApp.RBAC, authorize?: false)

      {:ok, role} ->
        role

      {:error, error} ->
        raise error
    end
  end

  defp upsert_user(%{email: email, password: password}) do
    User
    |> filter(email == ^email)
    |> Ash.read_one(domain: RbacApp.Accounts, authorize?: false)
    |> case do
      {:ok, nil} ->
        changeset =
          Ash.Changeset.for_create(
            User,
            :create,
            %{email: email, is_active: true},
            arguments: %{password: password}
          )

        Ash.create!(changeset, domain: RbacApp.Accounts, authorize?: false)

      {:ok, user} ->
        user

      {:error, error} ->
        raise error
    end
  end

  defp ensure_user_role(user, role) do
    UserRole
    |> filter(user_id == ^user.id and role_id == ^role.id)
    |> Ash.read_one(domain: RbacApp.RBAC, authorize?: false)
    |> case do
      {:ok, nil} ->
        changeset =
          Ash.Changeset.for_create(
            UserRole,
            :assign,
            %{user_id: user.id, role_id: role.id}
          )

        Ash.create!(changeset, domain: RbacApp.RBAC, authorize?: false)

      {:ok, _user_role} ->
        :ok

      {:error, error} ->
        raise error
    end
  end
end

RbacApp.Seeds.run()
