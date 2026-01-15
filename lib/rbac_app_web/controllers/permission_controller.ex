defmodule RbacAppWeb.PermissionController do
  use RbacAppWeb, :controller

  require Ash.Query

  alias RbacApp.Accounts.User
  alias RbacApp.RBAC.Role

  def show(conn, %{"username" => username, "role" => role_name}) do
    with {:ok, user} <- fetch_user(username),
         {:ok, role} <- fetch_role(role_name),
         :ok <- ensure_role_assigned(user, role) do
      effective_permissions = merge_permissions(role.permissions, user.permissions)

      json(conn, %{
        username: username,
        role: role_name,
        permissions: %{
          role: role.permissions || %{},
          user: user.permissions || %{},
          effective: effective_permissions
        }
      })
    else
      {:error, :missing_params} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "username and role are required parameters"})

      {:error, :user_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "User not found"})

      {:error, :role_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Role not found"})

      {:error, :role_not_assigned} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Role is not assigned to the specified user"})

      {:error, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: message})
    end
  end

  def show(conn, _params) do
    show(conn, %{"username" => nil, "role" => nil})
  end

  defp fetch_user(nil), do: {:error, :missing_params}
  defp fetch_user(""), do: {:error, :missing_params}

  defp fetch_user(username) do
    User
    |> Ash.Query.filter(email == ^username)
    |> Ash.Query.load(:roles)
    |> Ash.read_one(domain: RbacApp.Accounts, authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :user_not_found}
      {:ok, user} -> {:ok, user}
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  defp fetch_role(nil), do: {:error, :missing_params}
  defp fetch_role(""), do: {:error, :missing_params}

  defp fetch_role(role_name) do
    Role
    |> Ash.Query.filter(role_name == ^role_name)
    |> Ash.read_one(domain: RbacApp.RBAC, authorize?: false)
    |> case do
      {:ok, nil} -> {:error, :role_not_found}
      {:ok, role} -> {:ok, role}
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  defp ensure_role_assigned(user, role) do
    if Enum.any?(user.roles || [], &(&1.id == role.id)) do
      :ok
    else
      {:error, :role_not_assigned}
    end
  end

  defp merge_permissions(role_permissions, user_permissions) do
    role_permissions = role_permissions || %{}
    user_permissions = user_permissions || %{}

    role_permissions
    |> Map.merge(user_permissions, fn _resource, role_actions, user_actions ->
      combine_actions(role_actions, user_actions)
    end)
  end

  defp combine_actions(role_actions, user_actions) do
    actions =
      normalize_actions(role_actions) ++
        normalize_actions(user_actions)

    actions =
      actions
      |> Enum.uniq()

    if "*" in actions do
      ["*"]
    else
      actions
    end
  end

  defp normalize_actions(actions) when is_list(actions), do: actions
  defp normalize_actions("*"), do: ["*"]
  defp normalize_actions(nil), do: []
  defp normalize_actions(action), do: [to_string(action)]
end
