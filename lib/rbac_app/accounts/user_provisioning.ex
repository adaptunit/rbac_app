defmodule RbacApp.Accounts.UserProvisioning do
  @moduledoc """
  Transactional provisioning for a user:

  - create the user
  - optionally create a linked person record
  - optionally assign initial roles (via RBAC UserRole join rows)

  This is intended to keep UI/controller flows from re-implementing multi-step
  provisioning logic in different places.
  """

  require Ash.Query

  alias RbacApp.Accounts.{Person, User}
  alias RbacApp.RBAC.UserRole

  @type role_ids_input :: nil | String.t() | [String.t()]
  @type person_attrs :: nil | map()

  @spec provision_user(map(), person_attrs(), role_ids_input(), term()) ::
          {:ok, User.t()} | {:error, :forbidden | String.t()}
  def provision_user(user_attrs, person_attrs, role_ids, actor) when is_map(user_attrs) do
    role_ids = normalize_role_ids(role_ids)
    person_attrs = normalize_person_attrs(person_attrs)

    multi =
      Ash.Multi.new()
      |> Ash.Multi.create(:user, User, :create, user_attrs, domain: RbacApp.Accounts)
      |> maybe_create_person(person_attrs)
      |> add_role_assignments(role_ids)

    case Ash.Multi.run(multi, actor: actor, domain: RbacApp.Accounts) do
      {:ok, %{user: user}} ->
        load_user(user.id, actor)

      {:error, %Ash.Error.Forbidden{}} ->
        {:error, :forbidden}

      {:error, step, %Ash.Error.Forbidden{}, _changes} ->
        _ = step
        {:error, :forbidden}

      {:error, step, error, _changes} ->
        _ = step
        {:error, Exception.message(error)}

      {:error, error} ->
        {:error, Exception.message(error)}
    end
  end

  defp normalize_role_ids(nil), do: []
  defp normalize_role_ids(""), do: []
  defp normalize_role_ids(role_id) when is_binary(role_id), do: [role_id]
  defp normalize_role_ids(role_ids) when is_list(role_ids), do: Enum.reject(role_ids, &(&1 in [nil, ""]))
  defp normalize_role_ids(_), do: []

  defp normalize_person_attrs(nil), do: nil
  defp normalize_person_attrs(%{} = attrs) when map_size(attrs) == 0, do: nil
  defp normalize_person_attrs(%{} = attrs), do: attrs
  defp normalize_person_attrs(_), do: nil

  defp maybe_create_person(multi, nil), do: multi

  defp maybe_create_person(multi, %{} = person_attrs) do
    Ash.Multi.create(
      multi,
      :person,
      Person,
      :create,
      fn %{user: user} ->
        Map.put(person_attrs, :user_id, user.id)
      end,
      domain: RbacApp.Accounts
    )
  end

  defp add_role_assignments(multi, []), do: multi

  defp add_role_assignments(multi, role_ids) do
    Enum.reduce(Enum.with_index(role_ids, 1), multi, fn {role_id, idx}, acc ->
      Ash.Multi.create(
        acc,
        {:user_role, idx},
        UserRole,
        :assign,
        fn %{user: user} ->
          %{user_id: user.id, role_id: role_id}
        end,
        domain: RbacApp.RBAC
      )
    end)
  end

  defp load_user(user_id, actor) do
    query =
      User
      |> Ash.Query.filter(id == ^user_id)
      |> Ash.Query.load([:person, :roles])

    case Ash.read_one(query, actor: actor, domain: RbacApp.Accounts) do
      {:ok, user} ->
        {:ok, user}

      {:error, %Ash.Error.Forbidden{}} ->
        {:error, :forbidden}

      {:error, error} ->
        {:error, Exception.message(error)}
    end
  end
end
