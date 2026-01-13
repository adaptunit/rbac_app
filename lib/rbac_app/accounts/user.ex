defmodule RbacApp.Accounts.User do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication, AshAdmin.Resource],
    authorizers: [Ash.Policy.Authorizer],
    domain: RbacApp.Accounts

  admin do
    actor?(true)
  end

  postgres do
    table("users")
    repo(RbacApp.Repo)
  end

  attributes do
    # UUIDv7 at app-layer; DB default also set in migration to uuidv7()
    attribute(:id, :uuid, primary_key?: true, allow_nil?: false, default: &Ash.UUIDv7.generate/0)

    attribute(:email, :ci_string, allow_nil?: false, public?: true)
    attribute(:hashed_password, :string, allow_nil?: false, sensitive?: true, public?: false)

    attribute(:is_active, :boolean, allow_nil?: false, default: true)
    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_email, [:email])
  end

  relationships do
    has_one :person, RbacApp.Accounts.Person do
      destination_attribute(:user_id)
    end

    many_to_many :roles, RbacApp.RBAC.Role do
      through(RbacApp.RBAC.UserRole)
      source_attribute_on_join_resource(:user_id)
      destination_attribute_on_join_resource(:role_id)
    end
  end

  actions do
    defaults([:read])

    read :get_by_subject do
      argument(:subject, :string, allow_nil?: false)
      get?(true)
      prepare(AshAuthentication.Preparations.FilterBySubject)
    end
  end

  authentication do
    # +1 next steps
    session_identifier(:jti)

    tokens do
      enabled?(true)
      token_resource(RbacApp.Accounts.Token)
      store_all_tokens?(true)

      signing_secret(fn _, _ ->
        Application.fetch_env(:rbac_app, :token_signing_secret)
      end)
    end

    strategies do
      password :password do
        identity_field(:email)
        hashed_password_field(:hashed_password)
      end
    end
  end

  # Default: forbid everything unless explicitly allowed via policies/checks.
  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if(always())
    end

    policy always() do
      forbid_if(always())
    end
  end
end
