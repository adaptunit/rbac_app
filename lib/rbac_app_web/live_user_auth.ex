defmodule RbacAppWeb.LiveUserAuth do
  @moduledoc """
  LiveView `on_mount` hooks for AshAuthentication.

  Use these in your router via `ash_authentication_live_session`.
  """

  import Phoenix.Component
  use RbacAppWeb, :verified_routes

  def on_mount(:live_user_optional, _params, session, socket) do
    socket = assign_new(socket, :current_user, fn -> load_current_user(session) end)
    {:cont, socket}
  end

  def on_mount(:live_user_required, _params, session, socket) do
    socket = assign_new(socket, :current_user, fn -> load_current_user(session) end)

    if socket.assigns[:current_user] do
      {:cont, socket}
    else
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_no_user, _params, session, socket) do
    socket = assign_new(socket, :current_user, fn -> load_current_user(session) end)

    if socket.assigns[:current_user] do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      {:cont, socket}
    end
  end

  defp load_current_user(%{"user" => subject}) when is_binary(subject) do
    query = Ash.Query.for_read(RbacApp.Accounts.User, :get_by_subject, %{subject: subject})

    case Ash.read_one(query, domain: RbacApp.Accounts, authorize?: false) do
      {:ok, user} when not is_nil(user) ->
        Ash.load!(user, :roles, domain: RbacApp.RBAC, authorize?: false)

      _ ->
        nil
    end
  end

  defp load_current_user(_session), do: nil
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
