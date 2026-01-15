defmodule RbacAppWeb.Admin.RolesLive do
  use RbacAppWeb, :live_view

  require Ash.Query

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
    {roles, load_error} = fetch_roles(actor)

    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign(:page, :roles)
      |> assign(:roles_count, length(roles))
      |> assign(:role_options, role_options(roles))
      |> assign(:default_permissions, String.trim(@default_permissions))
      |> assign(:roles_form, build_role_form())
      |> assign(:role_select_form, build_role_select_form())
      |> assign(:role_edit_form, build_role_edit_form())
      |> assign(:selected_role_id, nil)
      |> assign(:roles_error, nil)
      |> assign(:edit_error, nil)
      |> assign(:load_error, load_error)
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
            <p :if={@load_error} class="mt-3 text-sm font-semibold text-rose-600">
              {@load_error}
            </p>
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
            <.link
              navigate={~p"/admin/access"}
              class={[
                "rounded-full px-4 py-2 transition",
                @page == :access && "bg-indigo-500 text-white shadow",
                @page != :access && "bg-white text-slate-600 hover:bg-slate-100"
              ]}
            >
              Access UI
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

            <section class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <h2 class="text-lg font-semibold text-slate-900">Edit role</h2>
              <p class="mt-2 text-sm text-slate-600">
                Refine permissions or rename a role without leaving the catalog.
              </p>

              <.form
                for={@role_select_form}
                id="role-edit-select-form"
                phx-change="load_role"
                class="mt-4"
              >
                <.input
                  field={@role_select_form[:role_id]}
                  type="select"
                  label="Select role"
                  options={@role_options}
                  prompt="Choose a role"
                />
              </.form>

              <%= if @selected_role_id do %>
                <.form for={@role_edit_form} id="role-edit-form" phx-submit="update_role" class="mt-6">
                  <.input field={@role_edit_form[:id]} type="hidden" />
                  <.input field={@role_edit_form[:role_name]} type="text" label="Role name" required />
                  <.input field={@role_edit_form[:description]} type="text" label="Description" />
                  <.input
                    field={@role_edit_form[:permissions]}
                    type="textarea"
                    label="Permissions JSON"
                    rows="10"
                    required
                  />

                  <p :if={@edit_error} class="mt-3 text-sm font-semibold text-rose-600">
                    {@edit_error}
                  </p>

                  <button
                    type="submit"
                    class="mt-4 w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm font-semibold text-slate-700 shadow-sm transition hover:-translate-y-0.5 hover:border-slate-300"
                  >
                    Save updates
                  </button>
                </.form>
              <% else %>
                <p class="mt-4 rounded-2xl border border-dashed border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-500">
                  Choose a role above to update its permissions and description.
                </p>
              <% end %>
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
       |> assign(:role_options, role_options(roles))
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
       |> assign(:role_options, role_options(roles))
       |> assign(:role_select_form, build_role_select_form())
       |> assign(:role_edit_form, build_role_edit_form())
       |> assign(:selected_role_id, nil)
       |> stream(:roles, roles, reset: true)
       |> put_flash(:info, "Role removed.")}
    else
      {:error, error_message} ->
        {:noreply, put_flash(socket, :error, error_message)}
    end
  end

  def handle_event("load_role", %{"role_select" => %{"role_id" => role_id}}, socket) do
    actor = socket.assigns[:current_user]

    case load_role_for_edit(role_id, actor) do
      {:ok, role} ->
        {:noreply,
         socket
         |> assign(:selected_role_id, role.id)
         |> assign(:role_edit_form, build_role_edit_form(role))
         |> assign(:role_select_form, build_role_select_form(role.id))
         |> assign(:edit_error, nil)}

      {:error, error_message} ->
        {:noreply,
         socket
         |> assign(:selected_role_id, nil)
         |> assign(:role_edit_form, build_role_edit_form())
         |> assign(:role_select_form, build_role_select_form())
         |> assign(:edit_error, error_message)}
    end
  end

  def handle_event("update_role", %{"role_edit" => params}, socket) do
    actor = socket.assigns[:current_user]
    role_id = Map.get(params, "id")

    with {:ok, role} <- load_role_for_edit(role_id, actor),
         {:ok, attrs} <- build_role_attrs(params),
         {:ok, _role} <- update_role(role, attrs, actor),
         {:ok, edited_role} <- load_role_for_edit(role_id, actor) do
      roles = list_roles(actor)

      {:noreply,
       socket
       |> assign(:role_edit_form, build_role_edit_form(edited_role))
       |> assign(:role_select_form, build_role_select_form(role_id))
       |> assign(:edit_error, nil)
       |> assign(:roles_count, length(roles))
       |> assign(:role_options, role_options(roles))
       |> stream(:roles, roles, reset: true)
       |> put_flash(:info, "Role updated successfully.")}
    else
      {:error, error_message} ->
        {:noreply, assign(socket, :edit_error, error_message)}
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

  defp build_role_select_form(role_id \\ "") do
    to_form(%{"role_id" => role_id}, as: :role_select)
  end

  defp build_role_edit_form(role \\ nil) do
    defaults = %{
      "id" => "",
      "role_name" => "",
      "description" => "",
      "permissions" => String.trim(@default_permissions)
    }

    form_values =
      case role do
        nil ->
          defaults

        _ ->
          Map.merge(defaults, %{
            "id" => role.id,
            "role_name" => role.role_name,
            "description" => role.description || "",
            "permissions" => Jason.encode!(role.permissions)
          })
      end

    to_form(form_values, as: :role_edit)
  end

  defp fetch_roles(actor) do
    Role
    |> Ash.read(domain: RbacApp.RBAC, actor: actor)
    |> handle_read_result("roles")
  end

  defp list_roles(actor) do
    {roles, _error} = fetch_roles(actor)
    roles
  end

  defp handle_read_result({:ok, records}, _label), do: {records, nil}

  defp handle_read_result({:error, %Ash.Error.Forbidden{}}, label) do
    {[], "You don't have permission to access #{label}."}
  end

  defp handle_read_result({:error, error}, label) do
    {[], "Unable to load #{label}: #{Exception.message(error)}"}
  end

  defp role_options(roles) do
    Enum.map(roles, &{&1.role_name, &1.id})
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

  defp load_role_for_edit("", _actor), do: {:error, "Select a role to edit."}
  defp load_role_for_edit(nil, _actor), do: {:error, "Select a role to edit."}

  defp load_role_for_edit(role_id, actor) do
    role =
      Role
      |> Ash.Query.filter(id == ^role_id)
      |> Ash.read_one(domain: RbacApp.RBAC, actor: actor)

    case role do
      {:ok, nil} -> {:error, "Selected role could not be found."}
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

  defp update_role(role, attrs, actor) do
    changeset = Ash.Changeset.for_update(role, :edit, attrs)

    case Ash.update(changeset, actor: actor, domain: RbacApp.RBAC) do
      {:ok, updated_role} -> {:ok, updated_role}
      {:error, error} -> {:error, Exception.message(error)}
    end
  end
end
