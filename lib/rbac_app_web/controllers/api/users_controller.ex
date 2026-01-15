defmodule RbacAppWeb.Api.UsersController do
  use RbacAppWeb, :controller

  require Ash.Query

  alias RbacApp.Accounts.{User, UserProvisioning}
  alias RbacApp.RBAC.RoleAssignments

  def index(conn, _params) do
    actor = conn.assigns[:current_user]

    User
    |> Ash.Query.load([:person, :roles])
    |> Ash.read(domain: RbacApp.Accounts, actor: actor)
    |> render_users(conn)
  end

  def show(conn, %{"id" => id}) do
    actor = conn.assigns[:current_user]

    case load_user(id, actor) do
      {:ok, user} ->
        json(conn, %{data: user_payload(user)})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "user not found"})

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

  def create(conn, %{"user" => user_params} = params) do
    actor = conn.assigns[:current_user]
    person_params = Map.get(params, "person")
    role_ids = Map.get(params, "role_ids")

    person_attrs_result =
      case person_params do
        nil -> {:ok, nil}
        %{} = attrs -> build_person_attrs(attrs)
        _ -> {:error, "Invalid person payload."}
      end

    with {:ok, user_attrs} <- build_user_attrs(user_params),
         {:ok, person_attrs} <- person_attrs_result,
         {:ok, loaded_user} <- UserProvisioning.provision_user(user_attrs, person_attrs, role_ids, actor) do
      conn
      |> put_status(:created)
      |> json(%{data: user_payload(loaded_user)})
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
    |> json(%{error: "user payload is required"})
  end

  def update(conn, %{"id" => id} = params) do
    actor = conn.assigns[:current_user]
    user_params = Map.get(params, "user", %{})
    person_params = Map.get(params, "person")

    if map_size(user_params) == 0 and is_nil(person_params) do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "user or person payload is required"})
    else
      person_attrs_result =
        case person_params do
          nil -> {:ok, nil}
          %{} = attrs -> build_person_attrs(attrs)
          _ -> {:error, "Invalid person payload."}
        end

      with {:ok, user} <- load_user(id, actor),
           {:ok, user_attrs} <- build_user_update_attrs(user_params),
           {:ok, person_attrs} <- person_attrs_result,
           {:ok, loaded_user} <- UserProvisioning.update_user_profile(user, user_attrs, person_attrs, actor) do
        json(conn, %{data: user_payload(loaded_user)})
      else
        {:error, :not_found} ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "user not found"})

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
  end

  def delete(conn, %{"id" => id}) do
    actor = conn.assigns[:current_user]

    with {:ok, user} <- load_user(id, actor),
         :ok <- Ash.destroy(user, actor: actor, domain: RbacApp.Accounts) do
      send_resp(conn, :no_content, "")
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "user not found"})

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

  def assign_roles(conn, %{"user_id" => user_id} = params) do
    actor = conn.assigns[:current_user]
    role_ids = Map.get(params, "role_ids")

    with {:ok, _user} <- load_user(user_id, actor),
         {:ok, _} <- RoleAssignments.sync_user_roles(user_id, role_ids, actor),
         {:ok, loaded_user} <- load_user(user_id, actor) do
      json(conn, %{data: user_payload(loaded_user)})
    else
      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "user not found"})

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

  def assign_roles(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "role_ids payload is required"})
  end

  defp render_users({:ok, users}, conn) do
    json(conn, %{data: Enum.map(users, &user_payload/1)})
  end

  defp render_users({:error, %Ash.Error.Forbidden{}}, conn) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "forbidden"})
  end

  defp render_users({:error, error}, conn) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{error: Exception.message(error)})
  end

  defp load_user(id, actor) do
    User
    |> Ash.Query.filter(id == ^id)
    |> Ash.Query.load([:person, :roles])
    |> Ash.read_one(domain: RbacApp.Accounts, actor: actor)
    |> case do
      {:ok, nil} -> {:error, :not_found}
      {:ok, user} -> {:ok, user}
      {:error, %Ash.Error.Forbidden{}} -> {:error, :forbidden}
      {:error, error} -> {:error, error}
    end
  end

  defp build_user_attrs(params) do
    email = Map.get(params, "email", "") |> String.trim()
    password = Map.get(params, "password", "") |> String.trim()
    is_active = Map.get(params, "is_active", true) |> normalize_boolean(true)

    cond do
      email == "" -> {:error, "Email is required."}
      password == "" -> {:error, "Password is required."}
      true -> {:ok, %{email: email, password: password, is_active: is_active}}
    end
  end

  defp build_user_update_attrs(params) do
    attrs = %{}
    email = Map.get(params, "email")
    is_active = Map.get(params, "is_active")

    attrs =
      if is_binary(email) do
        trimmed = String.trim(email)

        if trimmed == "" do
          attrs
        else
          Map.put(attrs, :email, trimmed)
        end
      else
        attrs
      end

    attrs =
      case normalize_boolean(is_active, nil) do
        nil -> attrs
        value -> Map.put(attrs, :is_active, value)
      end

    {:ok, attrs}
  end

  defp build_person_attrs(params) do
    first_name = Map.get(params, "first_name", "") |> String.trim()
    last_name = Map.get(params, "last_name", "") |> String.trim()
    emergency_contact_param = Map.get(params, "emergency_contact", %{})
    children_param = Map.get(params, "children", [])
    metadata_param = Map.get(params, "metadata", %{})

    with :ok <- validate_name(first_name, "First name"),
         :ok <- validate_name(last_name, "Last name"),
         {:ok, birthdate} <- parse_optional_date(Map.get(params, "birthdate")),
         {:ok, emergency_contact} <- parse_json_map(emergency_contact_param, "Emergency contact"),
         {:ok, children} <- parse_json_list(children_param, "Children"),
         {:ok, metadata} <- parse_json_map(metadata_param, "Metadata") do
      {:ok,
       %{
         first_name: first_name,
         last_name: last_name,
         middle_name: blank_to_nil(Map.get(params, "middle_name", "")),
         gender: blank_to_nil(Map.get(params, "gender", "")),
         birthdate: birthdate,
         nationality: blank_to_nil(Map.get(params, "nationality", "")),
         phone: blank_to_nil(Map.get(params, "phone", "")),
         phone_alt: blank_to_nil(Map.get(params, "phone_alt", "")),
         email_alt: blank_to_nil(Map.get(params, "email_alt", "")),
         address_line1: blank_to_nil(Map.get(params, "address_line1", "")),
         address_line2: blank_to_nil(Map.get(params, "address_line2", "")),
         city: blank_to_nil(Map.get(params, "city", "")),
         region: blank_to_nil(Map.get(params, "region", "")),
         postal_code: blank_to_nil(Map.get(params, "postal_code", "")),
         country: blank_to_nil(Map.get(params, "country", "")),
         emergency_contact: emergency_contact,
         children: children,
         notes: blank_to_nil(Map.get(params, "notes", "")),
         metadata: metadata
       }}
    end
  end

  defp validate_name("", label), do: {:error, "#{label} is required for the profile."}
  defp validate_name(_value, _label), do: :ok

  defp parse_optional_date(nil), do: {:ok, nil}
  defp parse_optional_date(""), do: {:ok, nil}
  defp parse_optional_date(%Date{} = date), do: {:ok, date}

  defp parse_optional_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, "Birthdate must be a valid ISO-8601 date (YYYY-MM-DD)."}
    end
  end

  defp parse_json_map(nil, _label), do: {:ok, %{}}
  defp parse_json_map(%{} = map, _label), do: {:ok, map}

  defp parse_json_map(value, label) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      {:ok, _} -> {:error, "#{label} must be a JSON object."}
      {:error, _} -> {:error, "#{label} must be valid JSON."}
    end
  end

  defp parse_json_map(_value, label), do: {:error, "#{label} must be a JSON object."}

  defp parse_json_list(nil, _label), do: {:ok, []}
  defp parse_json_list(list, _label) when is_list(list), do: {:ok, list}

  defp parse_json_list(value, label) when is_binary(value) do
    case Jason.decode(value) do
      {:ok, decoded} when is_list(decoded) -> {:ok, decoded}
      {:ok, _} -> {:error, "#{label} must be a JSON array."}
      {:error, _} -> {:error, "#{label} must be valid JSON."}
    end
  end

  defp parse_json_list(_value, label), do: {:error, "#{label} must be a JSON array."}

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp normalize_boolean(value, _default) when is_boolean(value), do: value
  defp normalize_boolean("true", _default), do: true
  defp normalize_boolean("false", _default), do: false
  defp normalize_boolean(nil, default), do: default
  defp normalize_boolean(_, default), do: default

  defp user_payload(user) do
    %{
      id: user.id,
      email: to_string(user.email),
      is_active: user.is_active,
      inserted_at: format_datetime(user.inserted_at),
      updated_at: format_datetime(user.updated_at),
      person: person_payload(user.person),
      roles: Enum.map(user_roles(user), &role_payload/1)
    }
  end

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

  defp person_payload(nil), do: nil
  defp person_payload(%Ash.NotLoaded{}), do: nil

  defp person_payload(person) do
    %{
      id: person.id,
      first_name: person.first_name,
      last_name: person.last_name,
      middle_name: person.middle_name,
      gender: person.gender,
      birthdate: person.birthdate && Date.to_iso8601(person.birthdate),
      nationality: person.nationality,
      phone: person.phone,
      phone_alt: person.phone_alt,
      email_alt: person.email_alt,
      address_line1: person.address_line1,
      address_line2: person.address_line2,
      city: person.city,
      region: person.region,
      postal_code: person.postal_code,
      country: person.country,
      emergency_contact: person.emergency_contact,
      children: person.children,
      notes: person.notes,
      metadata: person.metadata,
      inserted_at: format_datetime(person.inserted_at),
      updated_at: format_datetime(person.updated_at)
    }
  end

  defp user_roles(%User{roles: roles}) do
    cond do
      is_nil(roles) -> []
      match?(%Ash.NotLoaded{}, roles) -> []
      true -> roles
    end
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
