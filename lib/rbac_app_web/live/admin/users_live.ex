defmodule RbacAppWeb.Admin.UsersLive do
  use RbacAppWeb, :live_view

  require Ash.Query

  alias RbacApp.Accounts.{Person, User, UserProvisioning}
  alias RbacApp.RBAC.{Role, RoleAssignments}

  def mount(_params, _session, socket) do
    actor = socket.assigns[:current_user]
    {roles, roles_error} = fetch_roles(actor)
    {users, users_error} = fetch_users(actor)
    load_error = combine_errors([roles_error, users_error])

    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign(:page, :users)
      |> assign(:roles, roles)
      |> assign(:role_options, role_options(roles))
      |> assign(:user_options, user_options(users))
      |> assign(:user_count, length(users))
      |> assign(:user_form, build_user_form())
      |> assign(:edit_user_select_form, build_user_select_form())
      |> assign(:edit_user_form, build_user_edit_form())
      |> assign(:selected_user_id, nil)
      |> assign(:assignment_form, build_assignment_form())
      |> assign(:permission_select_form, build_permission_select_form())
      |> assign(:permission_form, build_permission_form())
      |> assign(:permission_user, nil)
      |> assign(:permission_error, nil)
      |> assign(:load_error, load_error)
      |> assign(:form_error, nil)
      |> assign(:edit_error, nil)
      |> assign(:assignment_error, nil)
      |> stream(:users, users)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-10">
        <header class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
          <div class="flex flex-col gap-6 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.35em] text-indigo-500">
                User directory
              </p>
              <h1 class="mt-2 text-3xl font-semibold text-slate-900">
                Create users, capture identity details, and assign roles.
              </h1>
              <p class="mt-2 text-sm text-slate-600">
                Manage onboarding, profile maintenance, and resource access from a unified control panel.
              </p>
              <p :if={@load_error} class="mt-3 text-sm font-semibold text-rose-600">
                {@load_error}
              </p>
            </div>
            <nav class="w-full lg:w-auto">
              <ul class="menu menu-horizontal w-full rounded-full bg-slate-50 p-1 text-sm font-semibold lg:w-auto">
                <li>
                  <.link
                    navigate={~p"/admin"}
                    class={[
                      "rounded-full px-4 py-2 transition",
                      @page == :dashboard && "active bg-indigo-500 text-white shadow-sm",
                      @page != :dashboard && "text-slate-600 hover:bg-white"
                    ]}
                  >
                    Overview
                  </.link>
                </li>
                <li>
                  <.link
                    navigate={~p"/admin/users"}
                    class={[
                      "rounded-full px-4 py-2 transition",
                      @page == :users && "active bg-indigo-500 text-white shadow-sm",
                      @page != :users && "text-slate-600 hover:bg-white"
                    ]}
                  >
                    Users
                  </.link>
                </li>
                <li>
                  <.link
                    navigate={~p"/admin/roles"}
                    class={[
                      "rounded-full px-4 py-2 transition",
                      @page == :roles && "active bg-indigo-500 text-white shadow-sm",
                      @page != :roles && "text-slate-600 hover:bg-white"
                    ]}
                  >
                    Roles
                  </.link>
                </li>
                <li>
                  <.link
                    navigate={~p"/admin/access"}
                    class={[
                      "rounded-full px-4 py-2 transition",
                      @page == :access && "active bg-indigo-500 text-white shadow-sm",
                      @page != :access && "text-slate-600 hover:bg-white"
                    ]}
                  >
                    Access UI
                  </.link>
                </li>
              </ul>
            </nav>
          </div>
        </header>

        <div class="grid gap-6 xl:grid-cols-[2fr_1fr]">
          <section class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <div class="flex flex-wrap items-center justify-between gap-4">
              <div>
                <h2 class="text-lg font-semibold text-slate-900">Active users</h2>
                <p class="text-sm text-slate-600">
                  The most recent user accounts with linked profile and role data.
                </p>
              </div>
              <span class="rounded-full border border-indigo-100 bg-indigo-50 px-3 py-1 text-xs font-semibold text-indigo-700">
                {@user_count} total
              </span>
            </div>

            <div class="mt-6 overflow-x-auto rounded-2xl border border-slate-200">
              <.table id="users" rows={@streams.users} row_item={fn {_id, user} -> user end}>
                <:col :let={user} label="User">
                  <div class="space-y-1">
                    <p class="text-sm font-semibold text-slate-900">{user.email}</p>
                    <p class="text-xs text-slate-500">
                      {person_label(user.person)}
                    </p>
                  </div>
                </:col>
                <:col :let={user} label="Contact">
                  <div class="space-y-1 text-xs text-slate-500">
                    <p>{person_contact(user.person)}</p>
                    <p>{person_location(user.person)}</p>
                  </div>
                </:col>
                <:col :let={user} label="Status">
                  <span class={[
                    "inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold",
                    user.is_active && "bg-emerald-50 text-emerald-700",
                    !user.is_active && "bg-slate-100 text-slate-500"
                  ]}>
                    {if(user.is_active, do: "Active", else: "Inactive")}
                  </span>
                </:col>
                <:col :let={user} label="Roles">
                  <div class="flex flex-wrap gap-2">
                    <%= for role <- user_roles(user) do %>
                      <span class="rounded-full bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-600">
                        {role.role_name}
                      </span>
                    <% end %>
                    <span :if={user_roles(user) == []} class="text-xs text-slate-400">No roles yet</span>
                  </div>
                </:col>
                <:col :let={user} label="Updated">
                  <span class="text-xs text-slate-500">{format_datetime(user.updated_at)}</span>
                </:col>
              </.table>
            </div>
          </section>

          <aside class="space-y-6">
            <section class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <div class="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <h2 class="text-lg font-semibold text-slate-900">Create user</h2>
                  <p class="mt-2 text-sm text-slate-600">
                    Register a new account and capture identity details in one flow.
                  </p>
                </div>
                <span class="badge badge-outline border-indigo-200 text-indigo-600">New account</span>
              </div>

              <.form for={@user_form} id="user-create-form" phx-submit="create_user" class="mt-6 space-y-6">
                <div class="space-y-4">
                  <h3 class="text-sm font-semibold uppercase tracking-[0.2em] text-slate-400">
                    Account credentials
                  </h3>
                  <div class="grid gap-4 sm:grid-cols-2">
                    <.input field={@user_form[:email]} type="email" label="Work email" required />
                    <.input field={@user_form[:password]} type="password" label="Temporary password" required />
                    <div class="sm:col-span-2">
                      <.input field={@user_form[:is_active]} type="checkbox" label="Activate immediately" />
                    </div>
                  </div>
                </div>

                <div class="space-y-4">
                  <h3 class="text-sm font-semibold uppercase tracking-[0.2em] text-slate-400">
                    Identity details
                  </h3>
                  <div class="grid gap-4 sm:grid-cols-2">
                    <.input field={@user_form[:first_name]} type="text" label="First name" required />
                    <.input field={@user_form[:middle_name]} type="text" label="Middle name" />
                    <.input field={@user_form[:last_name]} type="text" label="Last name" required />
                    <.input field={@user_form[:gender]} type="text" label="Gender" />
                    <.input field={@user_form[:birthdate]} type="date" label="Birthdate" />
                    <.input field={@user_form[:nationality]} type="text" label="Nationality" />
                  </div>
                </div>

                <div class="space-y-4">
                  <h3 class="text-sm font-semibold uppercase tracking-[0.2em] text-slate-400">
                    Contact & address
                  </h3>
                  <div class="grid gap-4 sm:grid-cols-2">
                    <.input field={@user_form[:phone]} type="tel" label="Primary phone" />
                    <.input field={@user_form[:phone_alt]} type="tel" label="Secondary phone" />
                    <.input field={@user_form[:email_alt]} type="email" label="Secondary email" />
                    <.input field={@user_form[:address_line1]} type="text" label="Address line 1" />
                    <.input field={@user_form[:address_line2]} type="text" label="Address line 2" />
                    <.input field={@user_form[:city]} type="text" label="City" />
                    <.input field={@user_form[:region]} type="text" label="Region/State" />
                    <.input field={@user_form[:postal_code]} type="text" label="Postal code" />
                    <.input field={@user_form[:country]} type="text" label="Country" />
                  </div>
                </div>

                <div class="space-y-4">
                  <h3 class="text-sm font-semibold uppercase tracking-[0.2em] text-slate-400">
                    Extended profile
                  </h3>
                  <div class="grid gap-4">
                    <.input
                      field={@user_form[:emergency_contact]}
                      type="textarea"
                      label="Emergency contact (JSON)"
                      rows="4"
                    />
                    <.input
                      field={@user_form[:children]}
                      type="textarea"
                      label="Children (JSON array)"
                      rows="4"
                    />
                    <.input field={@user_form[:notes]} type="textarea" label="Notes" rows="3" />
                    <.input field={@user_form[:metadata]} type="textarea" label="Metadata (JSON)" rows="4" />
                  </div>
                </div>

                <div class="space-y-4">
                  <h3 class="text-sm font-semibold uppercase tracking-[0.2em] text-slate-400">
                    Access scope
                  </h3>
                  <.input
                    field={@user_form[:role_ids]}
                    type="select"
                    label="Initial roles"
                    options={@role_options}
                    multiple
                  />
                  <p class="text-xs text-slate-500">
                    Assign one or more roles to seed the user's access levels on creation.
                  </p>
                </div>

                <p :if={@form_error} class="mt-3 text-sm font-semibold text-rose-600">
                  {@form_error}
                </p>

                <button type="submit" class="btn btn-primary w-full">
                  Create user
                </button>
              </.form>
            </section>

            <section class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <h2 class="text-lg font-semibold text-slate-900">Edit user profile</h2>
              <p class="mt-2 text-sm text-slate-600">
                Update contact, identity, and activation settings for an existing account.
              </p>

              <.form
                for={@edit_user_select_form}
                id="user-edit-select-form"
                phx-submit="load_user"
                phx-change="load_user"
                class="mt-4 grid gap-4 sm:grid-cols-[1fr_auto] sm:items-end"
              >
                <.input
                  field={@edit_user_select_form[:user_id]}
                  type="select"
                  label="Select user"
                  options={@user_options}
                  prompt="Choose a user"
                />
                <button type="submit" class="btn btn-primary btn-sm">
                  Load profile
                </button>
              </.form>

              <%= if @selected_user_id do %>
                <.form for={@edit_user_form} id="user-edit-form" phx-submit="update_user" class="mt-6 space-y-6">
                  <.input field={@edit_user_form[:id]} type="hidden" />
                  <div class="space-y-4">
                    <h3 class="text-sm font-semibold uppercase tracking-[0.2em] text-slate-400">
                      Account credentials
                    </h3>
                    <div class="grid gap-4 sm:grid-cols-2">
                      <.input field={@edit_user_form[:email]} type="email" label="Work email" required />
                      <div class="sm:col-span-2">
                        <.input field={@edit_user_form[:is_active]} type="checkbox" label="Account active" />
                      </div>
                    </div>
                  </div>

                  <div class="space-y-4">
                    <h3 class="text-sm font-semibold uppercase tracking-[0.2em] text-slate-400">
                      Identity details
                    </h3>
                    <div class="grid gap-4 sm:grid-cols-2">
                      <.input field={@edit_user_form[:first_name]} type="text" label="First name" required />
                      <.input field={@edit_user_form[:middle_name]} type="text" label="Middle name" />
                      <.input field={@edit_user_form[:last_name]} type="text" label="Last name" required />
                      <.input field={@edit_user_form[:gender]} type="text" label="Gender" />
                      <.input field={@edit_user_form[:birthdate]} type="date" label="Birthdate" />
                      <.input field={@edit_user_form[:nationality]} type="text" label="Nationality" />
                    </div>
                  </div>

                  <div class="space-y-4">
                    <h3 class="text-sm font-semibold uppercase tracking-[0.2em] text-slate-400">
                      Contact & address
                    </h3>
                    <div class="grid gap-4 sm:grid-cols-2">
                      <.input field={@edit_user_form[:phone]} type="tel" label="Primary phone" />
                      <.input field={@edit_user_form[:phone_alt]} type="tel" label="Secondary phone" />
                      <.input field={@edit_user_form[:email_alt]} type="email" label="Secondary email" />
                      <.input field={@edit_user_form[:address_line1]} type="text" label="Address line 1" />
                      <.input field={@edit_user_form[:address_line2]} type="text" label="Address line 2" />
                      <.input field={@edit_user_form[:city]} type="text" label="City" />
                      <.input field={@edit_user_form[:region]} type="text" label="Region/State" />
                      <.input field={@edit_user_form[:postal_code]} type="text" label="Postal code" />
                      <.input field={@edit_user_form[:country]} type="text" label="Country" />
                    </div>
                  </div>

                  <div class="space-y-4">
                    <h3 class="text-sm font-semibold uppercase tracking-[0.2em] text-slate-400">
                      Extended profile
                    </h3>
                    <div class="grid gap-4">
                      <.input
                        field={@edit_user_form[:emergency_contact]}
                        type="textarea"
                        label="Emergency contact (JSON)"
                        rows="4"
                      />
                      <.input
                        field={@edit_user_form[:children]}
                        type="textarea"
                        label="Children (JSON array)"
                        rows="4"
                      />
                      <.input field={@edit_user_form[:notes]} type="textarea" label="Notes" rows="3" />
                      <.input field={@edit_user_form[:metadata]} type="textarea" label="Metadata (JSON)" rows="4" />
                    </div>
                  </div>

                  <p :if={@edit_error} class="mt-3 text-sm font-semibold text-rose-600">
                    {@edit_error}
                  </p>

                  <button type="submit" class="btn btn-outline w-full">
                    Save updates
                  </button>
                </.form>
              <% else %>
                <p class="mt-4 rounded-2xl border border-dashed border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-500">
                  Choose a user above to begin editing their profile and account status.
                </p>
              <% end %>
            </section>

            <section class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <h2 class="text-lg font-semibold text-slate-900">Assign roles</h2>
              <p class="mt-2 text-sm text-slate-600">
                Update assignments without leaving this page.
              </p>
              <.form
                for={@assignment_form}
                id="role-assignment-form"
                phx-submit="assign_roles"
                class="mt-4 space-y-4"
              >
                <.input
                  field={@assignment_form[:user_id]}
                  type="select"
                  label="Select user"
                  options={@user_options}
                  prompt="Choose a user"
                  required
                />
                <.input
                  field={@assignment_form[:role_ids]}
                  type="select"
                  label="Assign roles"
                  options={@role_options}
                  multiple
                />

                <p :if={@assignment_error} class="mt-3 text-sm font-semibold text-rose-600">
                  {@assignment_error}
                </p>

                <button type="submit" class="btn btn-outline w-full">
                  Save assignments
                </button>
              </.form>
            </section>

            <section class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <h2 class="text-lg font-semibold text-slate-900">User resource access</h2>
              <p class="mt-2 text-sm text-slate-600">
                Grant route-based CRUD access that layers on top of role permissions.
              </p>

              <.form
                for={@permission_select_form}
                id="user-permission-select-form"
                phx-submit="load_permission_user"
                phx-change="load_permission_user"
                class="mt-4 grid gap-4 sm:grid-cols-[1fr_auto] sm:items-end"
              >
                <.input
                  field={@permission_select_form[:user_id]}
                  type="select"
                  label="Select user"
                  options={@user_options}
                  prompt="Choose a user"
                />
                <button type="submit" class="btn btn-primary btn-sm">
                  Load access
                </button>
              </.form>

              <%= if @permission_user do %>
                <div class="mt-4 rounded-2xl border border-slate-200 bg-slate-50 px-4 py-4">
                  <div class="flex items-center justify-between">
                    <h3 class="text-sm font-semibold uppercase tracking-[0.2em] text-slate-400">
                      Current permissions
                    </h3>
                    <span class="text-xs text-slate-500">
                      {length(permission_entries(@permission_user))} entries
                    </span>
                  </div>
                  <ul class="list mt-3">
                    <%= for {resource, actions} <- permission_entries(@permission_user) do %>
                      <li class="list-row bg-white">
                        <div class="list-col-grow">
                          <p class="text-sm font-semibold text-slate-900">{resource}</p>
                          <p class="text-xs text-slate-500">{format_actions(actions)}</p>
                        </div>
                        <div class="list-col-wrap flex items-center justify-end">
                          <button
                            type="button"
                            phx-click="remove_user_permission"
                            phx-value-user-id={@permission_user.id}
                            phx-value-resource={resource}
                            class="btn btn-ghost btn-xs text-rose-600"
                          >
                            Remove
                          </button>
                        </div>
                      </li>
                    <% end %>
                  </ul>
                  <p
                    :if={permission_entries(@permission_user) == []}
                    class="mt-3 rounded-2xl border border-dashed border-slate-200 bg-white px-4 py-3 text-sm text-slate-500"
                  >
                    No direct permissions yet. Add a route below.
                  </p>
                </div>

                <.form
                  for={@permission_form}
                  id="user-permission-form"
                  phx-submit="add_user_permission"
                  class="mt-6 space-y-4"
                >
                  <.input field={@permission_form[:user_id]} type="hidden" />
                  <.input
                    field={@permission_form[:resource]}
                    type="text"
                    label="Route / resource key"
                    placeholder="/admin/users"
                    required
                  />
                  <.input
                    field={@permission_form[:actions]}
                    type="select"
                    label="Allowed actions"
                    options={action_options()}
                    multiple
                    required
                  />

                  <p :if={@permission_error} class="text-sm font-semibold text-rose-600">
                    {@permission_error}
                  </p>

                  <button type="submit" class="btn btn-outline w-full">
                    Save permission
                  </button>
                </.form>
              <% else %>
                <p class="mt-4 rounded-2xl border border-dashed border-slate-200 bg-slate-50 px-4 py-3 text-sm text-slate-500">
                  Choose a user above to review or grant direct access.
                </p>
              <% end %>
            </section>
          </aside>
        </div>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("create_user", %{"user" => params}, socket) do
    actor = socket.assigns[:current_user]

    with {:ok, user_attrs} <- build_user_attrs(params),
         {:ok, person_attrs} <- build_person_attrs(params),
         {:ok, _user} <-
           UserProvisioning.provision_user(
             user_attrs,
             person_attrs,
             Map.get(params, "role_ids"),
             actor
           ) do
      users = list_users(actor)

      {:noreply,
       socket
       |> assign(:user_form, build_user_form())
       |> assign(:form_error, nil)
       |> assign(:user_options, user_options(users))
       |> assign(:user_count, length(users))
       |> stream(:users, users, reset: true)
       |> put_flash(:info, "User created and roles assigned.")}
    else
      {:error, error_message} ->
        {:noreply, assign(socket, :form_error, error_message)}
    end
  end

  def handle_event("assign_roles", %{"assignment" => params}, socket) do
    actor = socket.assigns[:current_user]

    case Map.get(params, "user_id") do
      nil ->
        {:noreply, assign(socket, :assignment_error, "Select a user to update.")}

      "" ->
        {:noreply, assign(socket, :assignment_error, "Select a user to update.")}

      user_id ->
        case RoleAssignments.sync_user_roles(user_id, Map.get(params, "role_ids"), actor) do
          {:ok, _} ->
            users = list_users(actor)

            {:noreply,
             socket
             |> assign(:assignment_form, build_assignment_form())
             |> assign(:assignment_error, nil)
             |> assign(:user_options, user_options(users))
             |> assign(:user_count, length(users))
             |> stream(:users, users, reset: true)
             |> put_flash(:info, "Role assignments updated.")}

          {:error, error_message} ->
            {:noreply, assign(socket, :assignment_error, error_message)}
        end
    end
  end

  def handle_event("load_user", %{"edit_select" => %{"user_id" => user_id}}, socket) do
    actor = socket.assigns[:current_user]

    case load_user_for_edit(user_id, actor) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:selected_user_id, user.id)
         |> assign(:edit_user_form, build_user_edit_form(user))
         |> assign(:edit_user_select_form, build_user_select_form(user.id))
         |> assign(:edit_error, nil)}

      {:error, error_message} ->
        {:noreply,
         socket
         |> assign(:selected_user_id, nil)
         |> assign(:edit_user_form, build_user_edit_form())
         |> assign(:edit_user_select_form, build_user_select_form())
         |> assign(:edit_error, error_message)}
    end
  end

  def handle_event("update_user", %{"user_edit" => params}, socket) do
    actor = socket.assigns[:current_user]
    user_id = Map.get(params, "id")

    with {:ok, user} <- load_user_for_edit(user_id, actor),
         {:ok, user_attrs} <- build_user_edit_attrs(params),
         {:ok, person_attrs} <- build_person_attrs(params),
         {:ok, _user} <- update_user(user, user_attrs, actor),
         {:ok, _person} <- upsert_person(user, person_attrs, actor),
         {:ok, edited_user} <- load_user_for_edit(user_id, actor) do
      users = list_users(actor)

      {:noreply,
       socket
       |> assign(:edit_user_form, build_user_edit_form(edited_user))
       |> assign(:edit_user_select_form, build_user_select_form(user_id))
       |> assign(:edit_error, nil)
       |> assign(:user_options, user_options(users))
       |> assign(:user_count, length(users))
       |> stream(:users, users, reset: true)
       |> put_flash(:info, "User profile updated.")}
    else
      {:error, error_message} ->
        {:noreply, assign(socket, :edit_error, error_message)}
    end
  end

  def handle_event("load_permission_user", %{"permission_select" => %{"user_id" => user_id}}, socket) do
    actor = socket.assigns[:current_user]

    case load_user_permissions(user_id, actor) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:permission_user, user)
         |> assign(:permission_select_form, build_permission_select_form(user.id))
         |> assign(:permission_form, build_permission_form(%{"user_id" => user.id}))
         |> assign(:permission_error, nil)}

      {:error, error_message} ->
        {:noreply,
         socket
         |> assign(:permission_user, nil)
         |> assign(:permission_select_form, build_permission_select_form())
         |> assign(:permission_form, build_permission_form())
         |> assign(:permission_error, error_message)}
    end
  end

  def handle_event("add_user_permission", %{"permission" => params}, socket) do
    actor = socket.assigns[:current_user]
    user_id = Map.get(params, "user_id")
    resource = Map.get(params, "resource", "") |> String.trim()
    actions = normalize_actions(Map.get(params, "actions"))

    with {:ok, user} <- load_user_permissions(user_id, actor),
         :ok <- validate_resource(resource),
         :ok <- validate_actions(actions),
         {:ok, updated_user} <- save_user_permission(user, resource, actions, actor) do
      users = list_users(actor)

      {:noreply,
       socket
       |> assign(:permission_user, updated_user)
       |> assign(:permission_form, build_permission_form(%{"user_id" => user_id}))
       |> assign(:permission_error, nil)
       |> assign(:user_options, user_options(users))
       |> assign(:user_count, length(users))
       |> stream(:users, users, reset: true)
       |> put_flash(:info, "User permission updated.")}
    else
      {:error, error_message} ->
        {:noreply, assign(socket, :permission_error, error_message)}
    end
  end

  def handle_event("remove_user_permission", %{"user-id" => user_id, "resource" => resource}, socket) do
    actor = socket.assigns[:current_user]

    with {:ok, user} <- load_user_permissions(user_id, actor),
         {:ok, updated_user} <- remove_user_permission(user, resource, actor) do
      users = list_users(actor)

      {:noreply,
       socket
       |> assign(:permission_user, updated_user)
       |> assign(:permission_error, nil)
       |> assign(:user_options, user_options(users))
       |> assign(:user_count, length(users))
       |> stream(:users, users, reset: true)
       |> put_flash(:info, "Permission removed.")}
    else
      {:error, error_message} ->
        {:noreply, assign(socket, :permission_error, error_message)}
    end
  end

  defp build_user_form(params \\ %{}) do
    defaults = %{
      "email" => "",
      "password" => "",
      "first_name" => "",
      "middle_name" => "",
      "last_name" => "",
      "gender" => "",
      "birthdate" => "",
      "nationality" => "",
      "phone" => "",
      "phone_alt" => "",
      "email_alt" => "",
      "address_line1" => "",
      "address_line2" => "",
      "city" => "",
      "region" => "",
      "postal_code" => "",
      "country" => "",
      "emergency_contact" => "{}",
      "children" => "[]",
      "notes" => "",
      "metadata" => "{}",
      "role_ids" => [],
      "is_active" => true
    }

    to_form(Map.merge(defaults, params), as: :user)
  end

  defp build_user_select_form(user_id \\ "") do
    to_form(%{"user_id" => user_id}, as: :edit_select)
  end

  defp build_user_edit_form(user \\ nil) do
    defaults = %{
      "id" => "",
      "email" => "",
      "first_name" => "",
      "middle_name" => "",
      "last_name" => "",
      "gender" => "",
      "birthdate" => "",
      "nationality" => "",
      "phone" => "",
      "phone_alt" => "",
      "email_alt" => "",
      "address_line1" => "",
      "address_line2" => "",
      "city" => "",
      "region" => "",
      "postal_code" => "",
      "country" => "",
      "emergency_contact" => "{}",
      "children" => "[]",
      "notes" => "",
      "metadata" => "{}",
      "is_active" => true
    }

    form_values =
      case user do
        nil ->
          defaults

        _ ->
          person = user.person

          Map.merge(defaults, %{
            "id" => user.id,
            "email" => to_string(user.email),
            "is_active" => user.is_active,
            "first_name" => person_value(person, :first_name),
            "middle_name" => person_value(person, :middle_name),
            "last_name" => person_value(person, :last_name),
            "gender" => person_value(person, :gender),
            "birthdate" => format_date(person && person.birthdate),
            "nationality" => person_value(person, :nationality),
            "phone" => person_value(person, :phone),
            "phone_alt" => person_value(person, :phone_alt),
            "email_alt" => person_value(person, :email_alt),
            "address_line1" => person_value(person, :address_line1),
            "address_line2" => person_value(person, :address_line2),
            "city" => person_value(person, :city),
            "region" => person_value(person, :region),
            "postal_code" => person_value(person, :postal_code),
            "country" => person_value(person, :country),
            "emergency_contact" => format_json_map(person && person.emergency_contact),
            "children" => format_json_list(person && person.children),
            "notes" => person_value(person, :notes),
            "metadata" => format_json_map(person && person.metadata)
          })
      end

    to_form(form_values, as: :user_edit)
  end

  defp build_assignment_form(params \\ %{}) do
    defaults = %{"user_id" => "", "role_ids" => []}
    to_form(Map.merge(defaults, params), as: :assignment)
  end

  defp build_permission_select_form(user_id \\ "") do
    to_form(%{"user_id" => user_id}, as: :permission_select)
  end

  defp build_permission_form(params \\ %{}) do
    defaults = %{"user_id" => "", "resource" => "", "actions" => []}
    to_form(Map.merge(defaults, params), as: :permission)
  end

  defp fetch_users(actor) do
    User
    |> Ash.Query.load([:person, :roles])
    |> Ash.read(domain: RbacApp.Accounts, actor: actor)
    |> handle_read_result("users")
  end

  defp list_users(actor) do
    {users, _error} = fetch_users(actor)
    users
  end

  defp fetch_roles(actor) do
    Role
    |> Ash.read(domain: RbacApp.RBAC, actor: actor)
    |> handle_read_result("roles")
  end

  defp handle_read_result({:ok, records}, _label), do: {records, nil}

  defp handle_read_result({:error, %Ash.Error.Forbidden{}}, label) do
    {[], "You don't have permission to access #{label}."}
  end

  defp handle_read_result({:error, error}, label) do
    {[], "Unable to load #{label}: #{Exception.message(error)}"}
  end

  defp combine_errors(errors) do
    errors
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      messages -> Enum.join(messages, " ")
    end
  end

  defp load_user_for_edit("", _actor), do: {:error, "Select a user to edit."}
  defp load_user_for_edit(nil, _actor), do: {:error, "Select a user to edit."}

  defp load_user_for_edit(user_id, actor) do
    user =
      User
      |> Ash.Query.filter(id == ^user_id)
      |> Ash.Query.load([:person, :roles])
      |> Ash.read_one(domain: RbacApp.Accounts, actor: actor)

    case user do
      {:ok, nil} -> {:error, "Selected user could not be found."}
      {:ok, user} -> {:ok, user}
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  defp load_user_permissions("", _actor), do: {:error, "Select a user to manage permissions."}
  defp load_user_permissions(nil, _actor), do: {:error, "Select a user to manage permissions."}

  defp load_user_permissions(user_id, actor) do
    user =
      User
      |> Ash.Query.filter(id == ^user_id)
      |> Ash.read_one(domain: RbacApp.Accounts, actor: actor)

    case user do
      {:ok, nil} -> {:error, "Selected user could not be found."}
      {:ok, user} -> {:ok, user}
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  defp role_options(roles) do
    Enum.map(roles, &{&1.role_name, &1.id})
  end

  defp user_options(users) do
    Enum.map(users, &{"#{&1.email} (#{person_label(&1.person)})", &1.id})
  end

  defp person_label(nil), do: "No profile"
  defp person_label(%Ash.NotLoaded{}), do: "No profile"

  defp person_label(person) do
    [person.first_name, person.middle_name, person.last_name]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" ")
    |> case do
      "" -> "No profile"
      name -> name
    end
  end

  defp person_contact(nil), do: "No contact details"
  defp person_contact(%Ash.NotLoaded{}), do: "No contact details"

  defp person_contact(person) do
    [person.phone, person.email_alt]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
    |> case do
      "" -> "No contact details"
      details -> details
    end
  end

  defp person_location(nil), do: "No location"
  defp person_location(%Ash.NotLoaded{}), do: "No location"

  defp person_location(person) do
    [person.city, person.region, person.country]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(", ")
    |> case do
      "" -> "No location"
      location -> location
    end
  end

  defp format_datetime(nil), do: "—"
  defp format_datetime(%NaiveDateTime{} = datetime), do: datetime |> NaiveDateTime.truncate(:second) |> NaiveDateTime.to_string()

  defp format_datetime(%DateTime{} = datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.truncate(:second)
    |> NaiveDateTime.to_string()
  end

  defp build_user_attrs(params) do
    email = Map.get(params, "email", "") |> String.trim()
    password = Map.get(params, "password", "") |> String.trim()
    is_active = Map.get(params, "is_active", "true") == "true"

    cond do
      email == "" -> {:error, "Email is required."}
      password == "" -> {:error, "Password is required."}
      true -> {:ok, %{email: email, password: password, is_active: is_active}}
    end
  end

  defp build_user_edit_attrs(params) do
    email = Map.get(params, "email", "") |> String.trim()
    is_active = Map.get(params, "is_active", "false") == "true"

    cond do
      email == "" -> {:error, "Email is required."}
      true -> {:ok, %{email: email, is_active: is_active}}
    end
  end

  defp build_person_attrs(params) do
    first_name = Map.get(params, "first_name", "") |> String.trim()
    last_name = Map.get(params, "last_name", "") |> String.trim()
    birthdate_input = Map.get(params, "birthdate", "") |> String.trim()

    with :ok <- validate_name(first_name, "First name"),
         :ok <- validate_name(last_name, "Last name"),
         {:ok, birthdate} <- parse_optional_date(birthdate_input),
         {:ok, emergency_contact} <- parse_json_map(Map.get(params, "emergency_contact")),
         {:ok, children} <- parse_json_list(Map.get(params, "children")),
         {:ok, metadata} <- parse_json_map(Map.get(params, "metadata")) do
      {:ok,
       %{
         first_name: first_name,
         last_name: last_name,
         middle_name: Map.get(params, "middle_name", "") |> blank_to_nil(),
         gender: Map.get(params, "gender", "") |> blank_to_nil(),
         birthdate: birthdate,
         nationality: Map.get(params, "nationality", "") |> blank_to_nil(),
         phone: Map.get(params, "phone", "") |> blank_to_nil(),
         phone_alt: Map.get(params, "phone_alt", "") |> blank_to_nil(),
         email_alt: Map.get(params, "email_alt", "") |> blank_to_nil(),
         address_line1: Map.get(params, "address_line1", "") |> blank_to_nil(),
         address_line2: Map.get(params, "address_line2", "") |> blank_to_nil(),
         city: Map.get(params, "city", "") |> blank_to_nil(),
         region: Map.get(params, "region", "") |> blank_to_nil(),
         postal_code: Map.get(params, "postal_code", "") |> blank_to_nil(),
         country: Map.get(params, "country", "") |> blank_to_nil(),
         emergency_contact: emergency_contact,
         children: children,
         notes: Map.get(params, "notes", "") |> blank_to_nil(),
         metadata: metadata
       }}
    end
  end

  defp create_person(user, attrs, actor) do
    changeset =
      Person
      |> Ash.Changeset.for_create(:create, Map.put(attrs, :user_id, user.id))

    case Ash.create(changeset, actor: actor, domain: RbacApp.Accounts) do
      {:ok, person} -> {:ok, person}
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  defp update_user(user, attrs, actor) do
    changeset = Ash.Changeset.for_update(user, :edit, attrs)

    case Ash.update(changeset, actor: actor, domain: RbacApp.Accounts) do
      {:ok, updated_user} -> {:ok, updated_user}
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  defp upsert_person(%User{person: nil} = user, attrs, actor) do
    create_person(user, attrs, actor)
  end

  defp upsert_person(%User{person: person}, attrs, actor) do
    changeset = Ash.Changeset.for_update(person, :edit, attrs)

    case Ash.update(changeset, actor: actor, domain: RbacApp.Accounts) do
      {:ok, updated_person} -> {:ok, updated_person}
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp person_value(nil, _field), do: ""
  defp person_value(%Ash.NotLoaded{}, _field), do: ""
  defp person_value(person, field), do: Map.get(person, field) || ""

  defp user_roles(%User{roles: roles}) do
    cond do
      is_nil(roles) -> []
      match?(%Ash.NotLoaded{}, roles) -> []
      true -> roles
    end
  end

  defp permission_entries(nil), do: []

  defp permission_entries(%User{} = user) do
    (user.permissions || %{})
    |> Map.to_list()
    |> Enum.sort_by(fn {resource, _actions} -> resource end)
  end

  defp format_actions(actions) when is_list(actions), do: Enum.join(actions, ", ")
  defp format_actions(action), do: to_string(action)

  defp action_options do
    [
      {"Create", "create"},
      {"Read", "read"},
      {"Update", "update"},
      {"Destroy", "destroy"}
    ]
  end

  defp validate_resource(""), do: {:error, "Route / resource key is required."}
  defp validate_resource(_), do: :ok

  defp validate_actions([]), do: {:error, "Select at least one action."}
  defp validate_actions(_actions), do: :ok

  defp normalize_actions(nil), do: []
  defp normalize_actions(""), do: []

  defp normalize_actions(actions) when is_list(actions) do
    actions
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.filter(&Enum.any?(action_options(), fn {_label, value} -> value == &1 end))
    |> Enum.uniq()
  end

  defp normalize_actions(action) when is_binary(action) do
    normalize_actions([action])
  end

  defp save_user_permission(user, resource, actions, actor) do
    permissions =
      (user.permissions || %{})
      |> Map.put(resource, actions)

    update_user_permissions(user, permissions, actor)
  end

  defp remove_user_permission(user, resource, actor) do
    permissions =
      (user.permissions || %{})
      |> Map.delete(resource)

    update_user_permissions(user, permissions, actor)
  end

  defp update_user_permissions(user, permissions, actor) do
    changeset = Ash.Changeset.for_update(user, :edit, %{permissions: permissions})

    case Ash.update(changeset, actor: actor, domain: RbacApp.Accounts) do
      {:ok, updated_user} -> {:ok, updated_user}
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  defp validate_name("", label), do: {:error, "#{label} is required for the profile."}
  defp validate_name(_value, _label), do: :ok

  defp parse_optional_date(""), do: {:ok, nil}

  defp parse_optional_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, "Birthdate must be a valid ISO-8601 date (YYYY-MM-DD)."}
    end
  end

  defp parse_json_map(nil), do: {:ok, %{}}
  defp parse_json_map(""), do: {:ok, %{}}

  defp parse_json_map(value) do
    case Jason.decode(value) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      {:ok, _} -> {:error, "Emergency contact/metadata must be a JSON object."}
      {:error, _} -> {:error, "Emergency contact/metadata must be valid JSON."}
    end
  end

  defp parse_json_list(nil), do: {:ok, []}
  defp parse_json_list(""), do: {:ok, []}

  defp parse_json_list(value) do
    case Jason.decode(value) do
      {:ok, decoded} when is_list(decoded) -> {:ok, decoded}
      {:ok, _} -> {:error, "Children must be a JSON array."}
      {:error, _} -> {:error, "Children must be valid JSON."}
    end
  end

  defp format_date(nil), do: ""
  defp format_date(%Date{} = date), do: Date.to_iso8601(date)

  defp format_json_map(nil), do: "{}"
  defp format_json_map(map) when is_map(map), do: Jason.encode!(map)
  defp format_json_map(_), do: "{}"

  defp format_json_list(nil), do: "[]"
  defp format_json_list(list) when is_list(list), do: Jason.encode!(list)
  defp format_json_list(_), do: "[]"
end
