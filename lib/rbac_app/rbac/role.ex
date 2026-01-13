efmodule RbacApp.RBAC.Role do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    domain: RbacApp.RBAC

  postgres do
    table("roles")
    repo(RbacApp.Repo)
  end

  attributes do
    attribute(:id, :uuid, primary_key?: true, allow_nil?: false, default: &Ash.UUIDv7.generate/0)
    attribute(:role_name, :string, allow_nil?: false)
    attribute(:description, :string)

    # JSONB permissions:
    # %{"accounts.user" => ["read", "create"], "accounts.person" => ["*"]}
    attribute(:permissions, :map, allow_nil?: false, default: %{})

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_role_name, [:role_name])
  end

  relationships do
    many_to_many :users, RbacApp.Accounts.User do
      through(RbacApp.RBAC.UserRole)
      source_attribute_on_join_resource(:role_id)
      destination_attribute_on_join_resource(:user_id)
    end
  end

  actions do
    defaults([:read, :create, :update, :destroy])

    create :create do
      accept([:role_name, :description, :permissions])
    end

    update :update do
      accept([:role_name, :description, :permissions])
    end
  end

  policies do
    # Only RBAC admins manage roles
    policy always() do
      authorize_if(RbacApp.Auth.Checks.HasPermission, permission: "rbac.role:*")
      forbid_if(always())
    end
  end
end
