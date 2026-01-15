defmodule RbacApp.RBAC.RoleAssignments do
  @moduledoc """
  Central place to sync a user's role assignments.

  Accepts role_ids as a list or a single value, tolerates nil/"".
  """

  require Ash.Query

  alias RbacApp.RBAC.UserRole

  @type role_id :: String.t()
  @type actor :: term()

  @spec sync_user_roles(role_id(), list(role_id()) | role_id() | nil, actor()) ::
          {:ok, %{added: non_neg_integer(), removed: non_neg_integer()}} | {:error, term()}
  def sync_user_roles(user_id, role_ids, actor) do
    desired_ids = normalize_role_ids(role_ids)

    with {:ok, existing_links} <- load_links(user_id, actor) do
      existing_ids = MapSet.new(Enum.map(existing_links, & &1.role_id))
      desired_set = MapSet.new(desired_ids)

      to_add = MapSet.difference(desired_set, existing_ids) |> MapSet.to_list()

      to_remove =
        existing_links
        |> Enum.filter(fn link -> not MapSet.member?(desired_set, link.role_id) end)

      multi =
        Ash.Multi.new()
        |> add_creates(user_id, to_add)
        |> add_destroys(to_remove)

      case Ash.Multi.run(multi, domain: RbacApp.RBAC, actor: actor) do
        {:ok, _result} ->
          {:ok, %{added: length(to_add), removed: length(to_remove)}}

        {:error, error} ->
          {:error, error}
      end
    end
  end

  defp load_links(user_id, actor) do
    UserRole
    |> Ash.Query.filter(user_id == ^user_id)
    |> Ash.read(domain: RbacApp.RBAC, actor: actor)
  end

  defp add_creates(multi, _user_id, []), do: multi

  defp add_creates(multi, user_id, role_ids) do
    Enum.reduce(Enum.with_index(role_ids), multi, fn {role_id, idx}, acc ->
      Ash.Multi.create(
        acc,
        {:assign_role, idx},
        UserRole,
        :assign,
        %{user_id: user_id, role_id: role_id}
      )
    end)
  end

  defp add_destroys(multi, []), do: multi

  defp add_destroys(multi, links) do
    Enum.reduce(Enum.with_index(links), multi, fn {link, idx}, acc ->
      Ash.Multi.destroy(acc, {:remove_role, idx}, link, domain: RbacApp.RBAC)
    end)
  end

  defp normalize_role_ids(nil), do: []
  defp normalize_role_ids(""), do: []

  defp normalize_role_ids(role_ids) when is_list(role_ids) do
    role_ids
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp normalize_role_ids(role_id) do
    normalize_role_ids([role_id])
  end
end
