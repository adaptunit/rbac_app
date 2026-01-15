defmodule RbacAppWeb.Admin.AccessLive do
  use RbacAppWeb, :live_view

  @login_schema """
  {
    "type": "object",
    "required": ["email", "password"],
    "properties": {
      "email": {"type": "string", "format": "email"},
      "password": {"type": "string", "minLength": 12},
      "remember_me": {"type": "boolean"}
    }
  }
  """

  @register_schema """
  {
    "type": "object",
    "required": ["email", "password", "password_confirmation"],
    "properties": {
      "email": {"type": "string", "format": "email"},
      "password": {"type": "string", "minLength": 12},
      "password_confirmation": {"type": "string", "minLength": 12},
      "workspace": {"type": "string"},
      "timezone": {"type": "string"}
    }
  }
  """

  @person_schema """
  {
    "type": "object",
    "required": ["first_name", "last_name", "email"],
    "properties": {
      "first_name": {"type": "string"},
      "last_name": {"type": "string"},
      "email": {"type": "string", "format": "email"},
      "department": {"type": "string"},
      "title": {"type": "string"},
      "phone": {"type": "string"},
      "identity_metadata": {"type": "object"}
    }
  }
  """

  @resource_schema """
  {
    "type": "object",
    "required": ["resource_name", "resource_type", "environment"],
    "properties": {
      "resource_name": {"type": "string"},
      "resource_type": {"type": "string"},
      "environment": {"type": "string"},
      "endpoint": {"type": "string", "format": "uri"},
      "owner": {"type": "string"},
      "tags": {"type": "array", "items": {"type": "string"}},
      "policies": {"type": "object"}
    }
  }
  """

  def mount(_params, _session, socket) do
    page_size = 5
    records = sample_records()
    {page_records, total_pages} = paginate_records(records, 1, page_size)

    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign(:page, :access)
      |> assign(:login_form, build_login_form())
      |> assign(:register_form, build_register_form())
      |> assign(:person_form, build_person_form())
      |> assign(:resource_form, build_resource_form())
      |> assign(:login_schema, String.trim(@login_schema))
      |> assign(:register_schema, String.trim(@register_schema))
      |> assign(:person_schema, String.trim(@person_schema))
      |> assign(:resource_schema, String.trim(@resource_schema))
      |> assign(:records, records)
      |> assign(:record_count, length(records))
      |> assign(:current_page, 1)
      |> assign(:total_pages, total_pages)
      |> assign(:page_size, page_size)
      |> stream(:records_stream, page_records)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-10">
        <header class="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div>
            <p class="text-sm font-semibold uppercase tracking-[0.2em] text-indigo-500">
              Access experience builder
            </p>
            <h1 class="mt-2 text-3xl font-semibold text-slate-900">
              Design authentication, identity, and resource flows with flexible validation.
            </h1>
            <p class="mt-3 max-w-3xl text-sm leading-6 text-slate-600">
              These UI blocks pair LiveView validation with JsonSchema-driven metadata so you can
              validate server-side, client-side, or both when connectivity is intermittent.
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

        <section class="grid gap-6 xl:grid-cols-[1.4fr_1fr]">
          <div class="space-y-6">
            <div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <h2 class="text-lg font-semibold text-slate-900">Login form</h2>
              <p class="mt-2 text-sm text-slate-600">
                Support passwordless, MFA, or device-bound sessions with pluggable validation layers.
              </p>

              <.form for={@login_form} id="login-form" class="mt-4 space-y-4">
                <.input field={@login_form[:email]} type="email" label="Email" required />
                <.input field={@login_form[:password]} type="password" label="Password" required />
                <.input field={@login_form[:remember_me]} type="checkbox" label="Remember this device" />
                <button
                  type="button"
                  class="w-full rounded-2xl bg-slate-900 px-4 py-3 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-slate-800"
                >
                  Sign in
                </button>
              </.form>
            </div>

            <div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <h2 class="text-lg font-semibold text-slate-900">Register form</h2>
              <p class="mt-2 text-sm text-slate-600">
                Capture workspace context and enforce strong passwords with LiveView feedback.
              </p>

              <.form for={@register_form} id="register-form" class="mt-4 space-y-4">
                <.input field={@register_form[:email]} type="email" label="Work email" required />
                <.input field={@register_form[:password]} type="password" label="Password" required />
                <.input
                  field={@register_form[:password_confirmation]}
                  type="password"
                  label="Confirm password"
                  required
                />
                <.input field={@register_form[:workspace]} type="text" label="Workspace" />
                <.input
                  field={@register_form[:timezone]}
                  type="select"
                  label="Primary timezone"
                  options={[{"UTC", "utc"}, {"GMT+1", "gmt+1"}, {"GMT+8", "gmt+8"}]}
                />
                <button
                  type="button"
                  class="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm font-semibold text-slate-700 shadow-sm transition hover:-translate-y-0.5 hover:border-slate-300"
                >
                  Create account
                </button>
              </.form>
            </div>
          </div>

          <aside class="space-y-6">
            <section class="rounded-3xl border border-indigo-100 bg-indigo-50/70 p-6">
              <h3 class="text-sm font-semibold uppercase tracking-[0.2em] text-indigo-600">
                Authentication JsonSchema
              </h3>
              <p class="mt-3 text-sm text-indigo-900/80">
                Store these schemas alongside your Hasura metadata so clients can validate even when
                offline. When the network reconnects, validate again on submit.
              </p>
              <div class="mt-4 space-y-4 text-xs text-slate-700">
                <div>
                  <p class="text-xs font-semibold text-slate-500">Login</p>
                  <pre class="mt-2 whitespace-pre-wrap rounded-2xl bg-white/90 p-4 shadow-sm" phx-no-curly-interpolation><%= @login_schema %></pre>
                </div>
                <div>
                  <p class="text-xs font-semibold text-slate-500">Register</p>
                  <pre class="mt-2 whitespace-pre-wrap rounded-2xl bg-white/90 p-4 shadow-sm" phx-no-curly-interpolation><%= @register_schema %></pre>
                </div>
              </div>
            </section>

            <section class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <h3 class="text-sm font-semibold uppercase tracking-[0.2em] text-slate-400">
                Validation strategy
              </h3>
              <p class="mt-3 text-sm text-slate-600">
                Choose where the form validates. Client-only flows can queue mutations until Hasura
                connectivity returns.
              </p>
              <div class="mt-4 space-y-3">
                <div class="flex items-center justify-between rounded-2xl border border-slate-200 px-4 py-3 text-sm text-slate-600">
                  <span>LiveView server validation</span>
                  <span class="rounded-full bg-emerald-50 px-3 py-1 text-xs font-semibold text-emerald-600">
                    Recommended
                  </span>
                </div>
                <div class="flex items-center justify-between rounded-2xl border border-slate-200 px-4 py-3 text-sm text-slate-600">
                  <span>Client-only JsonSchema validation</span>
                  <span class="rounded-full bg-slate-100 px-3 py-1 text-xs font-semibold text-slate-500">
                    Offline
                  </span>
                </div>
                <div class="flex items-center justify-between rounded-2xl border border-slate-200 px-4 py-3 text-sm text-slate-600">
                  <span>Hybrid (client + server)</span>
                  <span class="rounded-full bg-indigo-50 px-3 py-1 text-xs font-semibold text-indigo-600">
                    Best UX
                  </span>
                </div>
              </div>
            </section>
          </aside>
        </section>

        <section class="grid gap-6 lg:grid-cols-2">
          <div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 class="text-lg font-semibold text-slate-900">Person form</h2>
            <p class="mt-2 text-sm text-slate-600">
              Maintain a single source of identity truth for audits, provisioning, and HR alignment.
            </p>

            <.form for={@person_form} id="person-form" class="mt-4 space-y-4">
              <div class="grid gap-4 md:grid-cols-2">
                <.input field={@person_form[:first_name]} type="text" label="First name" required />
                <.input field={@person_form[:last_name]} type="text" label="Last name" required />
              </div>
              <div class="grid gap-4 md:grid-cols-2">
                <.input field={@person_form[:email]} type="email" label="Primary email" required />
                <.input field={@person_form[:phone]} type="tel" label="Phone number" />
              </div>
              <div class="grid gap-4 md:grid-cols-2">
                <.input field={@person_form[:department]} type="text" label="Department" />
                <.input field={@person_form[:title]} type="text" label="Job title" />
              </div>
              <.input
                field={@person_form[:identity_metadata]}
                type="textarea"
                label="Identity metadata (JSON)"
                rows="4"
              />
              <button
                type="button"
                class="w-full rounded-2xl border border-slate-200 bg-white px-4 py-3 text-sm font-semibold text-slate-700 shadow-sm transition hover:-translate-y-0.5 hover:border-slate-300"
              >
                Save profile
              </button>
            </.form>
          </div>

          <div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 class="text-lg font-semibold text-slate-900">Resource form</h2>
            <p class="mt-2 text-sm text-slate-600">
              Model APIs, SaaS tools, or internal services so roles can target explicit assets.
            </p>

            <.form for={@resource_form} id="resource-form" class="mt-4 space-y-4">
              <div class="grid gap-4 md:grid-cols-2">
                <.input field={@resource_form[:resource_name]} type="text" label="Resource name" required />
                <.input
                  field={@resource_form[:resource_type]}
                  type="select"
                  label="Resource type"
                  options={[{"API", "api"}, {"Database", "database"}, {"Dashboard", "dashboard"}]}
                  required
                />
              </div>
              <div class="grid gap-4 md:grid-cols-2">
                <.input field={@resource_form[:environment]} type="text" label="Environment" required />
                <.input field={@resource_form[:endpoint]} type="url" label="Endpoint" />
              </div>
              <div class="grid gap-4 md:grid-cols-2">
                <.input field={@resource_form[:owner]} type="text" label="Owner team" />
                <.input field={@resource_form[:tags]} type="text" label="Tags (comma separated)" />
              </div>
              <.input field={@resource_form[:policies]} type="textarea" label="Policies (JSON)" rows="4" />
              <button
                type="button"
                class="w-full rounded-2xl bg-slate-900 px-4 py-3 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-slate-800"
              >
                Create resource
              </button>
            </.form>
          </div>
        </section>

        <section class="grid gap-6 xl:grid-cols-[1.6fr_1fr]">
          <div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <div class="flex flex-wrap items-center justify-between gap-4">
              <div>
                <h2 class="text-lg font-semibold text-slate-900">Access records</h2>
                <p class="text-sm text-slate-600">
                  Paginated records prepared for Hasura-backed mutations and audit exports.
                </p>
              </div>
              <span class="rounded-full border border-indigo-100 bg-indigo-50 px-3 py-1 text-xs font-semibold text-indigo-700">
                {@record_count} records
              </span>
            </div>

            <div class="mt-6 overflow-x-auto rounded-2xl border border-slate-200">
              <.table id="access-records" rows={@streams.records_stream} row_item={fn {_id, record} -> record end}>
                <:col :let={record} label="Resource">
                  <div class="space-y-1">
                    <p class="text-sm font-semibold text-slate-900">{record.resource}</p>
                    <p class="text-xs text-slate-500">{record.environment}</p>
                  </div>
                </:col>
                <:col :let={record} label="Subject">
                  <div class="space-y-1 text-xs text-slate-500">
                    <p class="font-semibold text-slate-700">{record.subject}</p>
                    <p>{record.role}</p>
                  </div>
                </:col>
                <:col :let={record} label="Status">
                  <span class={[
                    "inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold",
                    record.status == "Active" && "bg-emerald-50 text-emerald-700",
                    record.status != "Active" && "bg-slate-100 text-slate-500"
                  ]}>
                    {record.status}
                  </span>
                </:col>
                <:col :let={record} label="Updated">
                  <span class="text-xs text-slate-500">{record.updated_at}</span>
                </:col>
                <:action :let={record}>
                  <button
                    type="button"
                    class="text-xs font-semibold text-indigo-600 transition hover:text-indigo-500"
                    aria-label={"Manage #{record.resource}"}
                  >
                    Manage
                  </button>
                </:action>
              </.table>
            </div>

            <div class="mt-6 flex flex-wrap items-center justify-between gap-4">
              <p class="text-sm text-slate-500">
                Page {@current_page} of {@total_pages}
              </p>
              <div class="flex items-center gap-2">
                <button
                  type="button"
                  phx-click="paginate"
                  phx-value-page={@current_page - 1}
                  disabled={@current_page == 1}
                  class={[
                    "inline-flex items-center gap-2 rounded-full border px-4 py-2 text-xs font-semibold transition",
                    @current_page == 1 && "cursor-not-allowed border-slate-100 text-slate-300",
                    @current_page != 1 && "border-slate-200 text-slate-600 hover:border-slate-300"
                  ]}
                >
                  <.icon name="hero-arrow-left" class="size-3" />
                  Previous
                </button>
                <button
                  type="button"
                  phx-click="paginate"
                  phx-value-page={@current_page + 1}
                  disabled={@current_page == @total_pages}
                  class={[
                    "inline-flex items-center gap-2 rounded-full border px-4 py-2 text-xs font-semibold transition",
                    @current_page == @total_pages && "cursor-not-allowed border-slate-100 text-slate-300",
                    @current_page != @total_pages && "border-slate-200 text-slate-600 hover:border-slate-300"
                  ]}
                >
                  Next
                  <.icon name="hero-arrow-right" class="size-3" />
                </button>
              </div>
            </div>
          </div>

          <aside class="space-y-6">
            <section class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <h3 class="text-sm font-semibold uppercase tracking-[0.2em] text-slate-400">
                Person JsonSchema
              </h3>
              <pre class="mt-4 whitespace-pre-wrap rounded-2xl bg-slate-50 p-4 text-xs text-slate-700" phx-no-curly-interpolation><%= @person_schema %></pre>
            </section>
            <section class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
              <h3 class="text-sm font-semibold uppercase tracking-[0.2em] text-slate-400">
                Resource JsonSchema
              </h3>
              <pre class="mt-4 whitespace-pre-wrap rounded-2xl bg-slate-50 p-4 text-xs text-slate-700" phx-no-curly-interpolation><%= @resource_schema %></pre>
            </section>
          </aside>
        </section>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    total_pages = socket.assigns.total_pages
    page = clamp_page(page, total_pages)

    {page_records, total_pages} =
      paginate_records(socket.assigns.records, page, socket.assigns.page_size)

    {:noreply,
     socket
     |> assign(:current_page, page)
     |> assign(:total_pages, total_pages)
     |> stream(:records_stream, page_records, reset: true)}
  end

  defp build_login_form(params \\ %{}) do
    defaults = %{"email" => "", "password" => "", "remember_me" => false}
    to_form(Map.merge(defaults, params), as: :login)
  end

  defp build_register_form(params \\ %{}) do
    defaults = %{
      "email" => "",
      "password" => "",
      "password_confirmation" => "",
      "workspace" => "",
      "timezone" => "utc"
    }

    to_form(Map.merge(defaults, params), as: :register)
  end

  defp build_person_form(params \\ %{}) do
    defaults = %{
      "first_name" => "",
      "last_name" => "",
      "email" => "",
      "phone" => "",
      "department" => "",
      "title" => "",
      "identity_metadata" => "{}"
    }

    to_form(Map.merge(defaults, params), as: :person)
  end

  defp build_resource_form(params \\ %{}) do
    defaults = %{
      "resource_name" => "",
      "resource_type" => "api",
      "environment" => "production",
      "endpoint" => "",
      "owner" => "",
      "tags" => "",
      "policies" => "{}"
    }

    to_form(Map.merge(defaults, params), as: :resource)
  end

  defp paginate_records(records, page, page_size) do
    total_pages =
      records
      |> length()
      |> Kernel./(page_size)
      |> Float.ceil()
      |> trunc()
      |> max(1)

    page = clamp_page(page, total_pages)
    start_index = (page - 1) * page_size
    {Enum.slice(records, start_index, page_size), total_pages}
  end

  defp clamp_page(page, _total_pages) when page < 1, do: 1
  defp clamp_page(page, total_pages) when page > total_pages, do: total_pages
  defp clamp_page(page, _total_pages), do: page

  defp sample_records do
    [
      %{id: "rec-01", resource: "Identity API", environment: "Production", subject: "Alicia Park", role: "Admin", status: "Active", updated_at: "2 minutes ago"},
      %{id: "rec-02", resource: "Billing Console", environment: "Staging", subject: "Jordan Lee", role: "Finance", status: "Active", updated_at: "12 minutes ago"},
      %{id: "rec-03", resource: "Support Hub", environment: "Production", subject: "Riley Smith", role: "Support", status: "Pending", updated_at: "30 minutes ago"},
      %{id: "rec-04", resource: "Data Lake", environment: "Production", subject: "Morgan Quinn", role: "Analyst", status: "Active", updated_at: "1 hour ago"},
      %{id: "rec-05", resource: "Audit Vault", environment: "Restricted", subject: "Jamie Chen", role: "Auditor", status: "Active", updated_at: "2 hours ago"},
      %{id: "rec-06", resource: "Ops Dashboard", environment: "Production", subject: "Taylor Kim", role: "Operator", status: "Inactive", updated_at: "Yesterday"},
      %{id: "rec-07", resource: "HRIS", environment: "Production", subject: "Chris Patel", role: "HR Manager", status: "Active", updated_at: "Yesterday"},
      %{id: "rec-08", resource: "Marketing Hub", environment: "Staging", subject: "Sydney Rivers", role: "Contributor", status: "Pending", updated_at: "2 days ago"},
      %{id: "rec-09", resource: "Partner Portal", environment: "Production", subject: "Casey Ibarra", role: "Partner", status: "Active", updated_at: "2 days ago"},
      %{id: "rec-10", resource: "Sales Console", environment: "Production", subject: "Sam Torres", role: "Sales", status: "Active", updated_at: "3 days ago"},
      %{id: "rec-11", resource: "Device Fleet", environment: "Production", subject: "Leslie Nguyen", role: "Ops", status: "Inactive", updated_at: "4 days ago"},
      %{id: "rec-12", resource: "Security Center", environment: "Restricted", subject: "Avery Johnson", role: "Security", status: "Active", updated_at: "5 days ago"}
    ]
  end
end
