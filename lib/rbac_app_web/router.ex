defmodule RbacAppWeb.Router do
  use RbacAppWeb, :router

  use AshAuthentication.Phoenix.Router
  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, {RbacAppWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
    plug(:load_from_session)
    plug(RbacAppWeb.Plugs.LoadActorRoles)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(:load_from_bearer)
    plug(:set_actor, :user)
  end

  pipeline :public_api do
    plug(:accepts, ["json"])
  end

  pipeline :graphql do
    plug(AshGraphql.Plug)
  end

  scope "/", RbacAppWeb do
    pipe_through(:browser)

    get("/", PageController, :home)

    # Controller-backed authentication routes
    auth_routes(AuthController, RbacApp.Accounts.User, path: "/auth")
    sign_out_route(AuthController)

    # Prebuilt auth LiveViews (sign-in/register/reset/etc)
    sign_in_route(
      register_path: "/register",
      reset_path: "/reset",
      auth_routes_prefix: "/auth",
      on_mount: [{RbacAppWeb.LiveUserAuth, :live_no_user}]
    )

    reset_route(auth_routes_prefix: "/auth")
  end

  # Example protected LiveView area (add your admin UI here)
  scope "/", RbacAppWeb do
    pipe_through(:browser)

    ash_authentication_live_session :authentication_required,
      on_mount: [{RbacAppWeb.LiveUserAuth, :live_user_required}] do
      live("/admin", Admin.DashboardLive, :index)
      live("/admin/users", Admin.UsersLive, :index)
      live("/admin/roles", Admin.RolesLive, :index)
      live("/admin/access", Admin.AccessLive, :index)
    end
  end

  # GraphQL endpoint (Absinthe)
  scope "/gql" do
    pipe_through([:graphql])

    forward(
      "/playground",
      Absinthe.Plug.GraphiQL,
      schema: Module.concat(["RbacAppWeb.Graphql.Schema"]),
      interface: :playground
    )

    forward(
      "/",
      Absinthe.Plug,
      schema: Module.concat(["RbacAppWeb.Graphql.Schema"])
    )
  end

  scope "/api", RbacAppWeb do
    pipe_through(:public_api)

    get("/permissions", PermissionController, :show)
  end

  if Application.compile_env(:rbac_app, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through(:browser)

      live_dashboard("/dashboard", metrics: RbacAppWeb.Telemetry)
    end
  end
end

# defmodule RbacAppWeb.Router do
#   use RbacAppWeb, :router

#   pipeline :browser do
#     plug :accepts, ["html"]
#     plug :fetch_session
#     plug :fetch_live_flash
#     plug :put_root_layout, html: {RbacAppWeb.Layouts, :root}
#     plug :protect_from_forgery
#     plug :put_secure_browser_headers
#   end

#   pipeline :api do
#     plug :accepts, ["json"]
#   end

#   scope "/", RbacAppWeb do
#     pipe_through :browser

#     get "/", PageController, :home
#   end

#   # Other scopes may use custom stacks.
#   # scope "/api", RbacAppWeb do
#   #   pipe_through :api
#   # end

#   # Enable LiveDashboard and Swoosh mailbox preview in development
#   if Application.compile_env(:rbac_app, :dev_routes) do
#     # If you want to use the LiveDashboard in production, you should put
#     # it behind authentication and allow only admins to access it.
#     # If your application does not have an admins-only section yet,
#     # you can use Plug.BasicAuth to set up some basic authentication
#     # as long as you are also using SSL (which you should anyway).
#     import Phoenix.LiveDashboard.Router

#     scope "/dev" do
#       pipe_through :browser

#       live_dashboard "/dashboard", metrics: RbacAppWeb.Telemetry
#       forward "/mailbox", Plug.Swoosh.MailboxPreview
#     end
#   end
# end
