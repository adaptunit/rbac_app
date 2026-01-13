defmodule RbacApp.Repo do
  use AshPostgres.Repo, otp_app: :rbac_app

  # Declare the minimum Postgres version this app supports
  def min_pg_version do
    %Version{major: 18, minor: 0, patch: 0}
  end

  # Optional: keep/extensions list if you use it
  def installed_extensions do
    ["ash-functions", "citext"]
  end
end

# defmodule RbacApp.Repo do
#   use AshPostgres.Repo, otp_app: :rbac_app
# end

# defmodule RbacApp.Repo do
#   use Ecto.Repo,
#     otp_app: :rbac_app,
#     adapter: Ecto.Adapters.Postgres
# end

# defmodule RbacApp.Repo do
#   use AshPostgres.Repo, otp_app: :rbac_app

#   # ash_authentication + ash_postgres commonly expect these extensions available :contentReference[oaicite:12]{index=12}
#   def installed_extensions do
#     # ash-functions provides SQL helpers used by AshPostgres
#     ["ash-functions", "citext"]
#   end
# end

# defmodule RbacApp.Repo do
#   use Ecto.Repo,
#     otp_app: :rbac_app,
#     adapter: Ecto.Adapters.Postgres
# end
