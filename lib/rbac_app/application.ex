defmodule RbacApp.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RbacApp.Repo,
      {Phoenix.PubSub, name: RbacApp.PubSub},
      RbacAppWeb.Endpoint,

      # AshAuthentication includes background cleanup etc. :contentReference[oaicite:13]{index=13}
      {AshAuthentication.Supervisor, otp_app: :rbac_app},

      # Oban (for ash_oban or app jobs)
      {Oban, Application.fetch_env!(:rbac_app, Oban)}
    ]

    opts = [strategy: :one_for_one, name: RbacApp.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    RbacAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

# defmodule RbacApp.Application do
#   # See https://hexdocs.pm/elixir/Application.html
#   # for more information on OTP Applications
#   @moduledoc false

#   use Application

#   @impl true
#   def start(_type, _args) do
#     children = [
#       RbacAppWeb.Telemetry,
#       RbacApp.Repo,
#       {DNSCluster, query: Application.get_env(:rbac_app, :dns_cluster_query) || :ignore},
#       {Phoenix.PubSub, name: RbacApp.PubSub},
#       # Start a worker by calling: RbacApp.Worker.start_link(arg)
#       # {RbacApp.Worker, arg},
#       # Start to serve requests, typically the last entry
#       RbacAppWeb.Endpoint
#     ]

#     # See https://hexdocs.pm/elixir/Supervisor.html
#     # for other strategies and supported options
#     opts = [strategy: :one_for_one, name: RbacApp.Supervisor]
#     Supervisor.start_link(children, opts)
#   end

#   # Tell Phoenix to update the endpoint configuration
#   # whenever the application is updated.
#   @impl true
#   def config_change(changed, _new, removed) do
#     RbacAppWeb.Endpoint.config_change(changed, removed)
#     :ok
#   end
# end
