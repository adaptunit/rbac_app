defmodule RbacAppWeb.Admin.DashboardLive do
  use RbacAppWeb, :live_view

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign_new(:current_scope, fn -> nil end)
      |> assign(:page, :dashboard)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-10">
        <div class="rounded-3xl border border-slate-200 bg-white/80 p-8 shadow-sm">
          <div class="flex flex-col gap-6 md:flex-row md:items-center md:justify-between">
            <div>
              <p class="text-sm font-semibold uppercase tracking-[0.2em] text-indigo-500">
                RBAC Command Center
              </p>
              <h1 class="mt-2 text-3xl font-semibold text-slate-900">
                Manage users, roles, and permissions with confidence.
              </h1>
              <p class="mt-3 max-w-2xl text-sm leading-6 text-slate-600">
                Control access across your organization with layered roles, auditable assignments,
                and unified identity data. Use the panels below to keep governance consistent and
                secure.
              </p>
            </div>
            <div class="flex gap-3">
              <.link
                navigate={~p"/admin/users"}
                class="inline-flex items-center justify-center rounded-full bg-slate-900 px-6 py-3 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-slate-800"
              >
                Manage users
              </.link>
              <.link
                navigate={~p"/admin/roles"}
                class="inline-flex items-center justify-center rounded-full border border-slate-200 bg-white px-6 py-3 text-sm font-semibold text-slate-700 shadow-sm transition hover:-translate-y-0.5 hover:border-slate-300"
              >
                Configure roles
              </.link>
            </div>
          </div>
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

        <div class="grid gap-6 lg:grid-cols-3">
          <div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 class="text-lg font-semibold text-slate-900">User lifecycle</h2>
            <p class="mt-2 text-sm leading-6 text-slate-600">
              Provision new users, capture identity data, and align roles with job functions.
            </p>
            <.link
              navigate={~p"/admin/users"}
              class="mt-6 inline-flex items-center gap-2 text-sm font-semibold text-indigo-600 transition hover:text-indigo-500"
            >
              Review users
              <.icon name="hero-arrow-right" class="size-4" />
            </.link>
          </div>
          <div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 class="text-lg font-semibold text-slate-900">Role governance</h2>
            <p class="mt-2 text-sm leading-6 text-slate-600">
              Design and curate permission sets across services with clear naming and scope.
            </p>
            <.link
              navigate={~p"/admin/roles"}
              class="mt-6 inline-flex items-center gap-2 text-sm font-semibold text-indigo-600 transition hover:text-indigo-500"
            >
              Audit roles
              <.icon name="hero-arrow-right" class="size-4" />
            </.link>
          </div>
          <div class="rounded-3xl border border-slate-200 bg-white p-6 shadow-sm">
            <h2 class="text-lg font-semibold text-slate-900">Assignments</h2>
            <p class="mt-2 text-sm leading-6 text-slate-600">
              Match users to the correct capabilities without over-privileging your teams.
            </p>
            <.link
              navigate={~p"/admin/users"}
              class="mt-6 inline-flex items-center gap-2 text-sm font-semibold text-indigo-600 transition hover:text-indigo-500"
            >
              Assign roles
              <.icon name="hero-arrow-right" class="size-4" />
            </.link>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
