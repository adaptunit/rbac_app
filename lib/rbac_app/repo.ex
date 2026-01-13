defmodule RbacApp.Repo do
  use AshPostgres.Repo, otp_app: :rbac_app

  # ash_authentication + ash_postgres commonly expect these extensions available :contentReference[oaicite:12]{index=12}
  def installed_extensions do
    # ash-functions provides SQL helpers used by AshPostgres
    ["ash-functions", "citext"]
  end
end

# defmodule RbacApp.Repo do
#   use Ecto.Repo,
#     otp_app: :rbac_app,
#     adapter: Ecto.Adapters.Postgres
# end
