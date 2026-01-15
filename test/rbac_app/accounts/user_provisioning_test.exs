defmodule RbacApp.Accounts.UserProvisioningTest do
  use RbacApp.DataCase, async: true

  alias RbacApp.Accounts.UserProvisioning
  alias RbacApp.RBAC.Role

  defp actor do
    %{
      id: Ash.UUID.generate(),
      roles: [
        %{
          permissions: %{
            "accounts.user" => ["*"],
            "accounts.person" => ["*"],
            "rbac.role" => ["*"],
            "rbac.user_role" => ["*"]
          }
        }
      ]
    }
  end

  test "provisions user, person, and roles in one flow" do
    actor = actor()

    {:ok, role} =
      Role
      |> Ash.Changeset.for_create(:create, %{
        role_name: "Admin",
        permissions: %{"accounts.user" => ["*"]}
      })
      |> Ash.create(actor: actor, domain: RbacApp.RBAC)

    user_attrs = %{
      email: "alice@example.com",
      password: "TempPass123!",
      is_active: true
    }

    person_attrs = %{
      first_name: "Alice",
      last_name: "Example"
    }

    {:ok, user} = UserProvisioning.provision_user(user_attrs, person_attrs, [role.id], actor)

    assert user.email == "alice@example.com"
    assert user.person.first_name == "Alice"
    assert Enum.any?(user.roles, &(&1.id == role.id))
  end
end
