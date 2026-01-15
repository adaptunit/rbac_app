defmodule RbacApp.Auth.Checks.HasPermission do
  @moduledoc """
  RBAC check: actor must have a role granting the requested permission.

  Permission format:
    - "resource.action"   e.g. "accounts.user.read"
    - "resource.*"        wildcard action
    - "resource:*"        same wildcard style (supported)
    - "*"
  """
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(opts), do: "requires permission #{inspect(opts[:permission])}"

  @impl true
  def match?(nil, _context, _opts), do: false

  def match?(actor, _context, opts) do
    required = to_string(Keyword.fetch!(opts, :permission))

    perms =
      actor
      |> combined_permissions()
      |> MapSet.new()

    MapSet.member?(perms, "*") or
      MapSet.member?(perms, required) or
      wildcard_match?(perms, required)
  end

  defp combined_permissions(actor) do
    role_permissions(actor) ++ user_permissions(actor)
  end

  defp role_permissions(actor) do
    roles = Map.get(actor, :roles, [])

    Enum.flat_map(roles, fn role ->
      role.permissions
      |> permissions_from_map()
    end)
  end

  defp user_permissions(actor) do
    actor
    |> Map.get(:permissions, %{})
    |> permissions_from_map()
  end

  defp permissions_from_map(nil), do: []

  defp permissions_from_map(permissions) when is_map(permissions) do
    Enum.flat_map(permissions, fn
      {resource, actions} when is_list(actions) ->
        Enum.map(actions, fn action ->
          normalize("#{resource}.#{action}")
        end)

      {resource, "*"} ->
        [normalize("#{resource}.*")]

      {_resource, _} ->
        []
    end)
  end

  defp wildcard_match?(perms, required) do
    required = normalize(required)

    case String.split(required, ".", parts: 2) do
      [resource, _action] ->
        MapSet.member?(perms, "#{resource}.*") or MapSet.member?(perms, "#{resource}:*")

      _ ->
        false
    end
  end

  defp normalize(str), do: String.replace(str, ":*", ".*")
end
