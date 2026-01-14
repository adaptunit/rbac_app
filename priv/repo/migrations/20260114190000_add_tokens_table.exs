defmodule RbacApp.Repo.Migrations.AddTokensTable do
  use Ecto.Migration

  def change do
    create table(:tokens, primary_key: false) do
      add(:jti, :text, primary_key: true, null: false)
      add(:subject, :text, null: false)
      add(:purpose, :text, null: false)
      add(:expires_at, :utc_datetime_usec, null: false)
      add(:created_at, :utc_datetime_usec, null: false)
      add(:updated_at, :utc_datetime_usec, null: false)
      add(:extra_data, :map, null: false, default: %{})
    end
  end
end
