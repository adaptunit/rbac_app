defmodule RbacAppWeb.Graphql.Schema do
  @moduledoc """
  Absinthe schema powered by AshGraphql.

  Add AshGraphql configurations on your Ash domains/resources to expose queries/mutations.
  """

  use Absinthe.Schema

  use AshGraphql,
    domains: [
      RbacApp.Accounts,
      RbacApp.RBAC
    ]

  query do
    @desc "Healthcheck"
    field :health, :string do
      resolve(fn _, _, _ -> {:ok, "ok"} end)
    end
  end

  mutation do
    # Custom mutations can go here
  end
end

# defmodule RbacAppWeb.Graphql.Schema do
#   use AshGraphql.Schema

#   domains([RbacApp.Accounts, RbacApp.RBAC])

#   # You can add context middleware later to set actor from bearer/session.
# end
