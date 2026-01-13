defmodule RbacAppWeb.AshAdminActorPlug do
  @moduledoc false
  @behaviour AshAdmin.ActorPlug

  @impl true
  def actor_assigns(socket, _session) do
    [actor: socket.assigns[:current_user]]
  end

  @impl true
  def set_actor_session(conn), do: conn
end
