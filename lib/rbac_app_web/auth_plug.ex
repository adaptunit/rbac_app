defmodule RbacAppWeb.AuthPlug do
  use AshAuthentication.Plug, otp_app: :rbac_app
  import Plug.Conn

  @hasura_namespace "https://hasura.io/jwt/claims"

  @impl true
  def handle_success(conn, _activity, user, _generated_token) do
    # Load roles and mint a Hasura-ready token with extra claims
    user = Ash.load!(user, :roles, domain: RbacApp.RBAC)
    role_names = Enum.map(user.roles, & &1.role_name)

    default_role = role_names |> List.first() |> Kernel.||("user")

    extra_claims = %{
      @hasura_namespace => %{
        "x-hasura-allowed-roles" => role_names,
        "x-hasura-default-role" => default_role,
        "x-hasura-user-id" => user.id
      }
    }

    {:ok, token, _claims} =
      AshAuthentication.Jwt.token_for_user(
        user,
        extra_claims,
        [purpose: "hasura"],
        %{}
      )

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{success: true, token: token, user_id: user.id}))
  end

  @impl true
  def handle_failure(conn, _activity, _reason) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{success: false}))
  end
end
