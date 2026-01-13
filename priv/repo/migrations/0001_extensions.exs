defmodule RbacApp.Repo.Migrations.Extensions do
  use Ecto.Migration

  def change do
    execute(~s(CREATE EXTENSION IF NOT EXISTS "citext";))
    execute(~s(CREATE EXTENSION IF NOT EXISTS "ash-functions";))
  end
end
