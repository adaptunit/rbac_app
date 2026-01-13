defmodule RbacApp.RBAC do
  use Ash.Domain, extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource(RbacApp.RBAC.Role)
    resource(RbacApp.RBAC.UserRole)
  end

  @spec role_names_for_user(RbacApp.Accounts.User.t()) :: [String.t()]
  def role_names_for_user(user) do
    user = Ash.load!(user, :roles, domain: __MODULE__)
    Enum.map(user.roles, & &1.role_name)
  end
end
