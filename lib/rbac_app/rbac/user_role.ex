defmodule RbacApp.RBAC.UserRole do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    domain: RbacApp.RBAC

  postgres do
    table("user_roles")
    repo(RbacApp.Repo)
  end

  attributes do
    attribute(:id, :uuid, primary_key?: true, allow_nil?: false, default: &Ash.UUIDv7.generate/0)
    attribute(:user_id, :uuid, allow_nil?: false)
    attribute(:role_id, :uuid, allow_nil?: false)

    create_timestamp(:inserted_at)
  end

  relationships do
    belongs_to :user, RbacApp.Accounts.User do
      source_attribute(:user_id)
      allow_nil?(false)
    end

    belongs_to :role, RbacApp.RBAC.Role do
      source_attribute(:role_id)
      allow_nil?(false)
    end
  end

  actions do
    defaults([:read, :create, :destroy])

    create :create do
      accept([:user_id, :role_id])
    end
  end

  policies do
    policy always() do
      authorize_if(RbacApp.Auth.Checks.HasPermission, permission: "rbac.user_role:*")
      forbid_if(always())
    end
  end
end
