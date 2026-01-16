defmodule RbacApp.Auth.Checks.HasPermissionTest do
  use ExUnit.Case, async: true

  alias RbacApp.Auth.Checks.HasPermission

  defp actor_with(perms) when is_map(perms) do
    %{
      roles: [%{permissions: perms}],
      permissions: %{}
    }
  end

  test "matches exact permission" do
    actor = actor_with(%{"accounts.user" => ["read"]})

    assert HasPermission.match?(actor, %{}, permission: "accounts.user.read")
  end

  test "matches resource wildcard (.*) from role map '*' action" do
    actor = actor_with(%{"accounts.person" => ["*"]})

    assert HasPermission.match?(actor, %{}, permission: "accounts.person.update")
    assert HasPermission.match?(actor, %{}, permission: "accounts.person:*")
  end

  test "matches namespace wildcard (accounts.*) if granted" do
    actor = actor_with(%{"accounts" => ["*"]})

    assert HasPermission.match?(actor, %{}, permission: "accounts.user.read")
    assert HasPermission.match?(actor, %{}, permission: "accounts.person.update")
  end

  test "does not match unrelated permissions" do
    actor = actor_with(%{"accounts.person" => ["read"]})

    refute HasPermission.match?(actor, %{}, permission: "accounts.user.read")
  end
end
