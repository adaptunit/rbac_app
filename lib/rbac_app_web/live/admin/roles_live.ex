defmodule RbacAppWeb.Admin.RolesLive do
  use RbacAppWeb, :live_view

  alias RbacApp.RBAC.Role

  @default_permissions """
  {
    "accounts.user": ["read", "create", "update", "destroy"],
    "accounts.person": ["read", "update"],
    "rbac.role": ["read", "create", "update", "destroy"],
    "rbac.user_role": ["read", "create", "destroy"]
  }
  """

  def mount(_params, _session, socket) do
    actor = socket.assigns[:current_user]
    roles = list_roles(actor)

    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign(:page, :roles)
      |> assign(:roles_count, length(roles))
      |> assign(:default_permissions, String.trim(@default_permissions))
      |> assign(:roles_form, build_role_form())
      |> assign(:roles_error, nil)
      |> stream(:roles, roles)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <header class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <p class="text-sm font-semibold uppercase tracking-[0.2em] text-indigo-500">
              Role governance
            </p>
            <h1 class="mt-2 text-3xl font-semibold text-slate-900">
              Define permission sets and keep access aligned to policy.
            </h1>
          </div>
          <nav class="flex flex-wrap gap-3 text-sm font-semibold">
            <.link
              navigate={~p"/admin"}
              class={[
                "rounded-full px-4 py-2 transition",
                @page == :dashboard && "bg-indigo-500 text-white shadow",
                @page != :dashboard && "bg-white text-slate-600 hover:bg-slate-100"
              ]}
            >
              Overview
            </.link>
            <.link
              navigate={~p"/admin/users"}
              class={[
                "rounded-full px-4 py-2 transition",
                @page == :users && "bg-indigo-500 text-white shadow",
                @page != :users && "bg-white text-slate-600 hover:bg-slate-100"
              ]}
            >
              Users
            </.link>
            <.link
              navigate={~p"/admin/roles"}
              class={[
                "rounded-full px-4 py-2 transition",
                @page == :roles && "bg-indigo-500 text-white shadow",
                @page != :roles && "bg-white text-slate-600 hover:bg-slate-100"
              ]}
            >
              Roles
            </.link>
          </nav>
        </header>

        <div class="grid gap-6 xl:grid-cols-[2fr_1fr]">
          <section class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <div class="flex flex-wrap items-center justify-between gap-4">
              <div>
                <h2 class="text-lg font-semibold text-slate-900">Role catalog</h2>
                <p class="text-sm text-slate-600">Review existing role definitions.</p>
              </div>
              <span class="rounded-full border border-indigo-100 bg-indigo-50 px-3 py-1 text-xs font-semibold text-indigo-700">
                {@roles_count} roles
              </span>
            </div>

            <div class="mt-6 overflow-x-auto rounded-2xl border border-slate-200">
              <.table id="roles" rows={@streams.roles} row_item={fn {_id, role} -> role end}>
                <:col :let={role} label="Role">
                  <div class="space-y-1">
                    <p class="text-sm font-semibold text-slate-900">{role.role_name}</p>
                    <p class="text-xs text-slate-500">{role.description || "No description yet"}</p>
                  </div>
                </:col>
                <:col :let={role} label="Permissions">
                  <div class="space-y-1 text-xs text-slate-500">
                    <%= for {resource, actions} <- role.permissions do %>
                      <p>
                        <span class="font-semibold text-slate-700">{resource}</span>
                        <span class="text-slate-400">•</span>
                        {format_actions(actions)}
                      </p>
                    <% end %>
                  </div>
                </:col>
                <:action :let={role}>
                  <button
                    type="button"
                    phx-click="delete_role"
                    phx-value-id={role.id}
                    class="text-xs font-semibold text-rose-600 transition hover:text-rose-500"
                  >
                    Remove
                  </button>
                </:action>
              </.table>
            </div>
          </section>

          <aside class="space-y-6">
            <section class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <h2 class="text-lg font-semibold text-slate-900">Create role</h2>
              <p class="mt-2 text-sm text-slate-600">
                Provide a role name and a permission map for resource operations.
              </p>

              <.form for={@roles_form} id="role-create-form" phx-submit="create_role" class="mt-4">
                <.input field={@roles_form[:role_name]} type="text" label="Role name" required />
                <.input field={@roles_form[:description]} type="text" label="Description" />
                <.input
                  field={@roles_form[:permissions]}
                  type="textarea"
                  label="Permissions JSON"
                  rows="10"
                  required
                />

                <p :if={@roles_error} class="mt-3 text-sm font-semibold text-rose-600">
                  {@roles_error}
                </p>

                <button
                  type="submit"
                  class="mt-4 w-full rounded-2xl bg-slate-900 px-4 py-3 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-slate-800"
                >
                  Save role
                </button>
              </.form>
            </section>

            <section class="rounded-3xl border border-indigo-100 bg-indigo-50/70 p-6">
              <h3 class="text-sm font-semibold uppercase tracking-[0.2em] text-indigo-600">
                Permission format
              </h3>
              <p class="mt-3 text-sm text-indigo-900/80">
                Use resource keys with action arrays. Wildcards (<span class="font-semibold">*</span>)
                grant full access within a resource.
              </p>
              <pre class="mt-4 whitespace-pre-wrap rounded-2xl bg-white/80 p-4 text-xs text-slate-700 shadow-sm" phx-no-curly-interpolation><%= @default_permissions %></pre>
            </section>
          </aside>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("create_role", %{"role" => params}, socket) do
    actor = socket.assigns[:current_user]

    with {:ok, attrs} <- build_role_attrs(params),
         {:ok, _role} <- create_role(attrs, actor) do
      roles = list_roles(actor)

      {:noreply,
       socket
       |> assign(:roles_form, build_role_form())
       |> assign(:roles_error, nil)
       |> assign(:roles_count, length(roles))
       |> stream(:roles, roles, reset: true)
       |> put_flash(:info, "Role created successfully.")}
    else
      {:error, error_message} ->
        {:noreply, assign(socket, :roles_error, error_message)}
    end
  end

  def handle_event("delete_role", %{"id" => id}, socket) do
    actor = socket.assigns[:current_user]

    with {:ok, _} <- delete_role(id, actor) do
      roles = list_roles(actor)

      {:noreply,
       socket
       |> assign(:roles_count, length(roles))
       |> stream(:roles, roles, reset: true)
       |> put_flash(:info, "Role removed.")}
    else
      {:error, error_message} ->
        {:noreply, put_flash(socket, :error, error_message)}
    end
  end

  defp build_role_form(params \\ %{}) do
    defaults = %{
      "role_name" => "",
      "description" => "",
      "permissions" => String.trim(@default_permissions)
    }
    to_form(Map.merge(defaults, params), as: :role)
  end

  defp list_roles(actor) do
    Ash.read!(Role, domain: RbacApp.RBAC, actor: actor)
  end

  defp build_role_attrs(params) do
    role_name = Map.get(params, "role_name", "") |> String.trim()
    description = Map.get(params, "description", "") |> blank_to_nil()
    permissions = Map.get(params, "permissions", "") |> String.trim()

    cond do
      role_name == "" ->
        {:error, "Role name is required."}

      permissions == "" ->
        {:error, "Permissions JSON cannot be empty."}

      true ->
        case Jason.decode(permissions) do
          {:ok, permissions_map} when is_map(permissions_map) ->
            {:ok, %{role_name: role_name, description: description, permissions: permissions_map}}

          {:ok, _} ->
            {:error, "Permissions must be a JSON object."}

          {:error, _} ->
            {:error, "Permissions must be valid JSON."}
        end
    end
  end

  defp create_role(attrs, actor) do
    changeset = Ash.Changeset.for_create(Role, :create, attrs)

    case Ash.create(changeset, actor: actor, domain: RbacApp.RBAC) do
      {:ok, role} -> {:ok, role}
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  defp delete_role(id, actor) do
    role =
      Role
      |> Ash.Query.filter(id == ^id)
      |> Ash.read_one!(domain: RbacApp.RBAC, actor: actor)

    case Ash.destroy(role, actor: actor, domain: RbacApp.RBAC) do
      :ok -> {:ok, :deleted}
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  defp format_actions(actions) when is_list(actions), do: Enum.join(actions, ", ")
  defp format_actions(action), do: to_string(action)

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
