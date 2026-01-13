defmodule RbacAppWeb.LiveUserAuth do
  @moduledoc """
  LiveView `on_mount` hooks for AshAuthentication.

  Use these in your router via `ash_authentication_live_session`.
  """

  import Phoenix.Component
  use RbacAppWeb, :verified_routes

  def on_mount(:live_user_optional, _params, _session, socket) do
    {:cont, assign_new(socket, :current_user, fn -> nil end)}
  end

  def on_mount(:live_user_required, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_no_user, _params, _session, socket) do
    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, assign_new(socket, :current_user, fn -> nil end)}
    end
  end
end

# defmodule RbacAppWeb.LiveUserAuth do
#   @moduledoc false
#   use AshAuthentication.Phoenix.LiveUserAuth, otp_app: :rbac_app

#   # Used by AshAdmin LiveSession opts
#   def on_mount(:admin_only, _params, _session, socket) do
#     user = socket.assigns[:current_user]

#     if user && Enum.any?(user.roles || [], &(&1.role_name == "admin")) do
#       {:cont, socket}
#     else
#       {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
#     end
#   end
# end
