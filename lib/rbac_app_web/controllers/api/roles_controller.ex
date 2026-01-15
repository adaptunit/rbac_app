defmodule RbacAppWeb.Api.RolesController do
  use RbacAppWeb, :controller

  require Ash.Query

  alias RbacApp.RBAC.Role

  def index(conn, _params) do
    actor = conn.assigns[:current_user]

    Role
    |> Ash.read(domain: RbacApp.RBAC, actor: actor)
    |> render_roles(conn)
  end

  def show(conn, %{"id" => id}) do
    actor = conn.assigns[:current_user]

    case load_role(id, actor) do
      {:ok, role} ->
        json(conn, %{data: role_payload(role)})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "role not found"})

      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden"})

      {:error, error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: Exception.message(error)})
    end
  end

  def create(conn, %{"role" => role_params}) do
    actor = conn.assigns[:current_user]

    with {:ok, attrs} <- build_role_attrs(role_params),
         {:ok, role} <- create_role(attrs, actor) do
      conn
      |> put_status(:created)
      |> json(%{data: role_payload(role)})
    else
      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden"})

      {:error, message} when is_binary(message) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: message})

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: Exception.message(error)})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "role payload is required"})
  end

  def update(conn, %{"id" => id} = params) do
    actor = conn.assigns[:current_user]
    role_params = Map.get(params, "role", %{})

    with {:ok, role} <- load_role(id, actor),
         {:ok, attrs} <- build_role_update_attrs(role_params),
         {:ok, updated_role} <- update_role(role, attrs, actor) do
      json(conn, %{data: role_payload(updated_role)})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "role not found"})

      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden"})

      {:error, message} when is_binary(message) ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: message})

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: Exception.message(error)})
    end
  end

  def delete(conn, %{"id" => id}) do
    actor = conn.assigns[:current_user]

    with {:ok, role} <- load_role(id, actor),
         :ok <- Ash.destroy(role, actor: actor, domain: RbacApp.RBAC) do
      send_resp(conn, :no_content, "")
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "role not found"})

      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden"})

      {:error, error} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: Exception.message(error)})
    end
  end

  defp render_roles({:ok, roles}, conn) do
    json(conn, %{data: Enum.map(roles, &role_payload/1)})
  end

  defp render_roles({:error, %Ash.Error.Forbidden{}}, conn) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "forbidden"})
  end

  defp render_roles({:error, error}, conn) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{error: Exception.message(error)})
  end

  defp load_role(id, actor) do
    Role
    |> Ash.Query.filter(id == ^id)
    |> Ash.read_one(domain: RbacApp.RBAC, actor: actor)
    |> case do
      {:ok, nil} -> {:error, :not_found}
      {:ok, role} -> {:ok, role}
      {:error, %Ash.Error.Forbidden{}} -> {:error, :forbidden}
      {:error, error} -> {:error, error}
    end
  end

  defp build_role_attrs(params) do
    role_name = Map.get(params, "role_name", "") |> String.trim()

    with :ok <- validate_role_name(role_name),
         {:ok, permissions} <- parse_permissions(Map.get(params, "permissions")) do
      {:ok,
       %{
         role_name: role_name,
         description: blank_to_nil(Map.get(params, "description", "")),
         permissions: permissions
       }}
    end
  end

  defp build_role_update_attrs(params) do
    attrs = %{}
    role_name = Map.get(params, "role_name")
    description = Map.get(params, "description")

    attrs =
      if is_binary(role_name) do
        trimmed = String.trim(role_name)

        if trimmed == "" do
          attrs
        else
          Map.put(attrs, :role_name, trimmed)
        end
      else
        attrs
      end

    attrs =
      if is_binary(description) do
        Map.put(attrs, :description, blank_to_nil(description))
      else
        attrs
      end

    {attrs, permissions_error} =
      case Map.fetch(params, "permissions") do
        :error ->
          {attrs, nil}

        {:ok, permissions_param} ->
          case parse_permissions(permissions_param) do
            {:ok, permissions} -> {Map.put(attrs, :permissions, permissions), nil}
            {:error, message} -> {attrs, message}
          end
      end

    cond do
      is_binary(permissions_error) ->
        {:error, permissions_error}

      map_size(attrs) == 0 ->
        {:error, "No role attributes were provided."}

      true ->
        {:ok, attrs}
    end
  end

  defp create_role(attrs, actor) do
    Role
    |> Ash.Changeset.for_create(:create, attrs)
    |> Ash.create(actor: actor, domain: RbacApp.RBAC)
    |> handle_resource_action()
  end

  defp update_role(role, attrs, actor) do
    role
    |> Ash.Changeset.for_update(:edit, attrs)
    |> Ash.update(actor: actor, domain: RbacApp.RBAC)
    |> handle_resource_action()
  end

  defp handle_resource_action({:ok, result}), do: {:ok, result}
  defp handle_resource_action(:ok), do: {:ok, :ok}
  defp handle_resource_action({:error, %Ash.Error.Forbidden{}}), do: {:error, :forbidden}
  defp handle_resource_action({:error, error}), do: {:error, error}

  defp validate_role_name(""), do: {:error, "Role name is required."}
  defp validate_role_name(_), do: :ok

  defp parse_permissions(nil), do: {:ok, %{}}
  defp parse_permissions(%{} = permissions), do: {:ok, permissions}

  defp parse_permissions(permissions) when is_binary(permissions) do
    case Jason.decode(permissions) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      {:ok, _} -> {:error, "Permissions must be a JSON object."}
      {:error, _} -> {:error, "Permissions must be valid JSON."}
    end
  end

  defp parse_permissions(_), do: {:error, "Permissions must be a JSON object."}

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp role_payload(role) do
    %{
      id: role.id,
      role_name: role.role_name,
      description: role.description,
      permissions: role.permissions,
      inserted_at: format_datetime(role.inserted_at),
      updated_at: format_datetime(role.updated_at)
    }
  end

  defp format_datetime(nil), do: nil

  defp format_datetime(%NaiveDateTime{} = datetime) do
    datetime
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_iso8601()
  end

  defp format_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_iso8601()
  end
end
