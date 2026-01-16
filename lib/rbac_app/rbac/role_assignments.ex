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

      with :ok <- create_links(user_id, to_add, actor),
           :ok <- destroy_links(to_remove, actor) do
        {:ok, %{added: length(to_add), removed: length(to_remove)}}
      end
    end
  end

  defp load_links(user_id, actor) do
    UserRole
    |> Ash.Query.filter(user_id == ^user_id)
    |> Ash.read(domain: RbacApp.RBAC, actor: actor)
  end

  defp create_links(_user_id, [], _actor), do: :ok

  defp create_links(user_id, role_ids, actor) do
    Enum.reduce_while(role_ids, :ok, fn role_id, :ok ->
      changeset =
        UserRole
        |> Ash.Changeset.for_create(:assign, %{user_id: user_id, role_id: role_id})

      case Ash.create(changeset, actor: actor, domain: RbacApp.RBAC) do
        {:ok, _record} -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp destroy_links([], _actor), do: :ok

  defp destroy_links(links, actor) do
    Enum.reduce_while(links, :ok, fn link, :ok ->
      case Ash.destroy(link, actor: actor, domain: RbacApp.RBAC) do
        :ok -> {:cont, :ok}
        {:ok, _record} -> {:cont, :ok}
        {:error, error} -> {:halt, {:error, error}}
      end
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
