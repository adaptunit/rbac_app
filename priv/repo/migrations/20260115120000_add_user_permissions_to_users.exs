defmodule RbacApp.Repo.Migrations.AddUserPermissionsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add(:permissions, :map, null: false, default: %{})
    end
  end
end
