defmodule RbacApp.Accounts do
  use Ash.Domain, extensions: [AshAdmin.Domain]

  admin do
    show?(true)
  end

  resources do
    resource(RbacApp.Accounts.User)
    resource(RbacApp.Accounts.Person)
    resource(RbacApp.Accounts.Token)
  end
end
