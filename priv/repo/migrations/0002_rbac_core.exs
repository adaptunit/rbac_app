defmodule RbacApp.Repo.Migrations.RbacCore do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false, default: fragment("uuidv7()"))
      add(:email, :citext, null: false)
      add(:hashed_password, :text, null: false)
      add(:is_active, :boolean, null: false, default: true)

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:users, [:email]))

    create table(:people, primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false, default: fragment("uuidv7()"))
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false)

      add(:first_name, :text, null: false)
      add(:last_name, :text, null: false)
      add(:middle_name, :text)
      add(:gender, :text)
      add(:birthdate, :date)
      add(:nationality, :text)

      add(:phone, :text)
      add(:phone_alt, :text)
      add(:email_alt, :text)

      add(:address_line1, :text)
      add(:address_line2, :text)
      add(:city, :text)
      add(:region, :text)
      add(:postal_code, :text)
      add(:country, :text)

      add(:emergency_contact, :map, null: false, default: %{})
      add(:children, {:array, :map}, null: false, default: [])
      add(:notes, :text)
      add(:metadata, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:people, [:user_id]))

    create table(:roles, primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false, default: fragment("uuidv7()"))
      add(:role_name, :text, null: false)
      add(:description, :text)
      add(:permissions, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:roles, [:role_name]))

    create table(:user_roles, primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false, default: fragment("uuidv7()"))
      add(:user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false)
      add(:role_id, references(:roles, type: :uuid, on_delete: :delete_all), null: false)

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create(unique_index(:user_roles, [:user_id, :role_id]))
    create(index(:user_roles, [:role_id]))
  end
end
