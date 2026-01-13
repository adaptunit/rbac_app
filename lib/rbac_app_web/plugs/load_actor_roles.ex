defmodule RbacAppWeb.Plugs.LoadActorRoles do
  @moduledoc false
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      nil ->
        conn

      user ->
        user = Ash.load!(user, :roles, domain: RbacApp.RBAC)
        assign(conn, :current_user, user)
    end
  end
end
