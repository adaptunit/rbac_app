defmodule RbacApp.Accounts.Person do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    domain: RbacApp.Accounts

  postgres do
    table("people")
    repo(RbacApp.Repo)
  end

  attributes do
    attribute(:id, :uuid, primary_key?: true, allow_nil?: false, default: &Ash.UUIDv7.generate/0)
    attribute(:user_id, :uuid, allow_nil?: false)

    attribute(:first_name, :string, allow_nil?: false)
    attribute(:last_name, :string, allow_nil?: false)
    attribute(:middle_name, :string)
    attribute(:gender, :string)
    attribute(:birthdate, :date)
    attribute(:nationality, :string)

    # Contact
    attribute(:phone, :string)
    attribute(:phone_alt, :string)
    attribute(:email_alt, :string)

    # Address
    attribute(:address_line1, :string)
    attribute(:address_line2, :string)
    attribute(:city, :string)
    attribute(:region, :string)
    attribute(:postal_code, :string)
    attribute(:country, :string)

    # “Much more”
    attribute(:emergency_contact, :map, default: %{})
    attribute(:children, {:array, :map}, default: [])
    attribute(:notes, :string)
    attribute(:metadata, :map, default: %{})

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :user, RbacApp.Accounts.User do
      source_attribute(:user_id)
      allow_nil?(false)
    end
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      accept([
        :user_id,
        :first_name,
        :last_name,
        :middle_name,
        :gender,
        :birthdate,
        :nationality,
        :phone,
        :phone_alt,
        :email_alt,
        :address_line1,
        :address_line2,
        :city,
        :region,
        :postal_code,
        :country,
        :emergency_contact,
        :children,
        :notes,
        :metadata
      ])
    end

    update :edit do
      accept([
        :first_name,
        :last_name,
        :middle_name,
        :gender,
        :birthdate,
        :nationality,
        :phone,
        :phone_alt,
        :email_alt,
        :address_line1,
        :address_line2,
        :city,
        :region,
        :postal_code,
        :country,
        :emergency_contact,
        :children,
        :notes,
        :metadata
      ])
    end
  end

  # actions do
  #   defaults([:read, :create, :update, :destroy])

  #   create :create do
  #     accept([
  #       :user_id,
  #       :first_name,
  #       :last_name,
  #       :middle_name,
  #       :gender,
  #       :birthdate,
  #       :nationality,
  #       :phone,
  #       :phone_alt,
  #       :email_alt,
  #       :address_line1,
  #       :address_line2,
  #       :city,
  #       :region,
  #       :postal_code,
  #       :country,
  #       :emergency_contact,
  #       :children,
  #       :notes,
  #       :metadata
  #     ])
  #   end

  #   update :update do
  #     accept([
  #       :first_name,
  #       :last_name,
  #       :middle_name,
  #       :gender,
  #       :birthdate,
  #       :nationality,
  #       :phone,
  #       :phone_alt,
  #       :email_alt,
  #       :address_line1,
  #       :address_line2,
  #       :city,
  #       :region,
  #       :postal_code,
  #       :country,
  #       :emergency_contact,
  #       :children,
  #       :notes,
  #       :metadata
  #     ])
  #   end
  # end

  policies do
    # RBAC: if the actor has a role granting "accounts.person:*", allow everything and skip other policies.
    bypass always() do
      authorize_if({RbacApp.Auth.Checks.HasPermission, permission: "accounts.person:*"})
    end

    # Self-access: a user may read/update their own Person row
    policy action_type([:read, :update]) do
      authorize_if(expr(user_id == ^actor(:id)))
    end
  end

  # policies do
  #   # Admin can do everything on Person
  #   policy action_type(:*) do
  #     authorize_if(RbacApp.Auth.Checks.HasPermission, permission: "accounts.person:*")
  #   end

  #   # Users can read/update their own Person
  #   policy action_type([:read, :update]) do
  #     authorize_if(expr(user_id == ^actor(:id)))
  #   end

  #   policy always() do
  #     forbid_if(always())
  #   end
  # end
end
