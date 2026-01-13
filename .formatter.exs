[
  import_deps: [
    :phoenix,
    :phoenix_live_view,
    :ash,
    :ash_postgres,
    :ash_phoenix,
    :ash_authentication
  ],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"]
]

# [
#   import_deps: [:ecto, :ecto_sql, :phoenix],
#   subdirectories: ["priv/*/migrations"],
#   plugins: [Phoenix.LiveView.HTMLFormatter],
#   inputs: ["*.{heex,ex,exs}", "{config,lib,test}/**/*.{heex,ex,exs}", "priv/*/seeds.exs"]
# ]
