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
  @type user_update_attrs :: nil | map()

  @spec provision_user(map(), person_attrs(), role_ids_input(), term()) ::
          {:ok, User.t()} | {:error, :forbidden | String.t()}
  def provision_user(user_attrs, person_attrs, role_ids, actor) when is_map(user_attrs) do
    role_ids = normalize_role_ids(role_ids)
    person_attrs = normalize_person_attrs(person_attrs)

    result =
      Ash.DataLayer.transaction(User, fn ->
        with {:ok, user} <-
               Ash.create(User, user_attrs,
                 action: :create,
                 actor: actor,
                 domain: RbacApp.Accounts
               ),
             {:ok, _person} <- maybe_create_person(user, person_attrs, actor),
             {:ok, _assignments} <- add_role_assignments(user, role_ids, actor),
             {:ok, user} <- load_user(user.id, actor) do
          user
        else
          {:error, error} -> Ash.DataLayer.rollback(User, error)
        end
      end)

    handle_transaction_result(result)
  end

  @doc """
  Transactionally updates a user (if attributes provided) and upserts the user's person profile.

  This is meant to consolidate the LiveView/controller "update user + upsert person" multi-step flow
  into a single transaction.
  """
  @spec update_user_profile(User.t(), map(), person_attrs(), term()) ::
          {:ok, User.t()} | {:error, :forbidden | String.t()}
  def update_user_profile(%User{} = user, user_attrs, person_attrs, actor) when is_map(user_attrs) do
    user_attrs = normalize_user_update_attrs(user_attrs)
    person_attrs = normalize_person_attrs(person_attrs)

    result =
      Ash.DataLayer.transaction(User, fn ->
        with {:ok, user} <- maybe_update_user(user, user_attrs, actor),
             {:ok, _person} <- maybe_upsert_person(user, person_attrs, actor),
             {:ok, user} <- load_user(user.id, actor) do
          user
        else
          {:error, error} -> Ash.DataLayer.rollback(User, error)
        end
      end)

    handle_transaction_result(result)
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

  defp normalize_user_update_attrs(nil), do: nil
  defp normalize_user_update_attrs(%{} = attrs) when map_size(attrs) == 0, do: nil
  defp normalize_user_update_attrs(%{} = attrs), do: attrs
  defp normalize_user_update_attrs(_), do: nil

  defp maybe_create_person(_user, nil, _actor), do: {:ok, nil}

  defp maybe_create_person(%User{} = user, %{} = person_attrs, actor) do
    attrs = Map.put(person_attrs, :user_id, user.id)

    Ash.create(Person, attrs, action: :create, actor: actor, domain: RbacApp.Accounts)
  end

  defp maybe_update_user(%User{} = user, nil, _actor), do: {:ok, user}

  defp maybe_update_user(%User{} = user, %{} = user_attrs, actor) do
    changeset = Ash.Changeset.for_update(user, :edit, user_attrs)

    Ash.update(changeset, actor: actor, domain: RbacApp.Accounts)
  end

  defp maybe_upsert_person(_user, nil, _actor), do: {:ok, nil}

  defp maybe_upsert_person(%User{} = user, %{} = person_attrs, actor) do
    case user.person do
      %Person{} = person ->
        changeset = Ash.Changeset.for_update(person, :edit, person_attrs)
        Ash.update(changeset, actor: actor, domain: RbacApp.Accounts)

      _ ->
        attrs = Map.put(person_attrs, :user_id, user.id)
        Ash.create(Person, attrs, action: :create, actor: actor, domain: RbacApp.Accounts)
    end
  end

  defp add_role_assignments(_user, [], _actor), do: {:ok, []}

  defp add_role_assignments(%User{} = user, role_ids, actor) do
    Enum.reduce_while(role_ids, {:ok, []}, fn role_id, {:ok, acc} ->
      case Ash.create(
             UserRole,
             %{user_id: user.id, role_id: role_id},
             action: :assign,
             actor: actor,
             domain: RbacApp.RBAC
           ) do
        {:ok, assignment} -> {:cont, {:ok, [assignment | acc]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp load_user(user_id, actor) do
    query =
      User
      |> Ash.Query.filter(id == ^user_id)
      |> Ash.Query.load([:person, :roles])

    Ash.read_one(query, actor: actor, domain: RbacApp.Accounts)
  end

  defp handle_transaction_result({:ok, user}), do: {:ok, user}

  defp handle_transaction_result({:error, %Ash.Error.Forbidden{}}), do: {:error, :forbidden}

  defp handle_transaction_result({:error, :forbidden}), do: {:error, :forbidden}

  defp handle_transaction_result({:error, error}) when is_binary(error), do: {:error, error}

  defp handle_transaction_result({:error, error}),
    do: {:error, Exception.message(error)}
end
