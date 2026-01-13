defmodule RbacApp.Repo.Migrations.AddOban do
  use Ecto.Migration

  # generated
  # def change do

  # end
  def up, do: Oban.Migrations.up(version: 13)
  def down, do: Oban.Migrations.down(version: 13)
end
