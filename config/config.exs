import Config

config :rbac_app,
  ecto_repos: [RbacApp.Repo]

#  ash_domains: [RbacApp.Accounts, RbacApp.RBAC]

config :rbac_app, RbacApp.Repo,
  migration_primary_key: [name: :id, type: :binary_id],
  migration_foreign_key: [type: :binary_id]

config :rbac_app, Oban,
  repo: RbacApp.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10]

# AshAdmin actor plug (optional; implemented below)
config :ash_admin, :actor_plug, RbacAppWeb.AshAdminActorPlug

# # This file is responsible for configuring your application
# # and its dependencies with the aid of the Config module.
# #
# # This configuration file is loaded before any dependency and
# # is restricted to this project.

# # General application configuration
# import Config

# config :rbac_app,
#   ecto_repos: [RbacApp.Repo],
#   generators: [timestamp_type: :utc_datetime]

# # Configure the endpoint
# config :rbac_app, RbacAppWeb.Endpoint,
#   url: [host: "localhost"],
#   adapter: Bandit.PhoenixAdapter,
#   render_errors: [
#     formats: [html: RbacAppWeb.ErrorHTML, json: RbacAppWeb.ErrorJSON],
#     layout: false
#   ],
#   pubsub_server: RbacApp.PubSub,
#   live_view: [signing_salt: "Qng+YXaT"]

# # Configure the mailer
# #
# # By default it uses the "Local" adapter which stores the emails
# # locally. You can see the emails in your browser, at "/dev/mailbox".
# #
# # For production it's recommended to configure a different adapter
# # at the `config/runtime.exs`.
# config :rbac_app, RbacApp.Mailer, adapter: Swoosh.Adapters.Local

# # Configure esbuild (the version is required)
# config :esbuild,
#   version: "0.25.4",
#   rbac_app: [
#     args:
#       ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
#     cd: Path.expand("../assets", __DIR__),
#     env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
#   ]

# # Configure tailwind (the version is required)
# config :tailwind,
#   version: "4.1.12",
#   rbac_app: [
#     args: ~w(
#       --input=assets/css/app.css
#       --output=priv/static/assets/css/app.css
#     ),
#     cd: Path.expand("..", __DIR__)
#   ]

# # Configure Elixir's Logger
# config :logger, :default_formatter,
#   format: "$time $metadata[$level] $message\n",
#   metadata: [:request_id]

# # Use Jason for JSON parsing in Phoenix
# config :phoenix, :json_library, Jason

# # Import environment specific config. This must remain at the bottom
# # of this file so it overrides the configuration defined above.
#
#

config :esbuild, version: "0.25.0"

config :tailwind, version: "4.1.12"

# --- Profiles used by watchers in dev.exs ---
config :esbuild,
  rbac_app: [
    args:
      ~w(js/app.js --bundle --target=es2017 --sourcemap=inline --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  rbac_app: [
    args: ~w(
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

import_config "#{config_env()}.exs"
