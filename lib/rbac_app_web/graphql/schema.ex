defmodule RbacAppWeb.Graphql.Schema do
  use AshGraphql.Schema

  domains([RbacApp.Accounts, RbacApp.RBAC])

  # You can add context middleware later to set actor from bearer/session.
end
