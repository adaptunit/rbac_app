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

  test "updates user and upserts person in one flow" do
    actor = actor()

    user_attrs = %{
      email: "bob@example.com",
      password: "TempPass123!",
      is_active: true
    }

    person_attrs = %{
      first_name: "Bob",
      last_name: "Example"
    }

    {:ok, user} = UserProvisioning.provision_user(user_attrs, person_attrs, [], actor)

    update_user_attrs = %{
      email: "bob+updated@example.com"
    }

    update_person_attrs = %{
      first_name: "Bobby",
      last_name: "Example"
    }

    {:ok, updated_user} =
      UserProvisioning.update_user_profile(user, update_user_attrs, update_person_attrs, actor)

    assert updated_user.email == "bob+updated@example.com"
    assert updated_user.person.first_name == "Bobby"
  end
end
