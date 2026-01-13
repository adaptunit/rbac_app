defmodule RbacAppWeb.LiveUserAuth do
  @moduledoc false
  use AshAuthentication.Phoenix.LiveUserAuth, otp_app: :rbac_app

  # Used by AshAdmin LiveSession opts
  def on_mount(:admin_only, _params, _session, socket) do
    user = socket.assigns[:current_user]

    if user && Enum.any?(user.roles || [], &(&1.role_name == "admin")) do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    end
  end
end
