defmodule RbacApp.Repo.Migrations.Extensions do
  use Ecto.Migration

  def change do
    execute(~S|CREATE EXTENSION IF NOT EXISTS "citext";|)
    # IMPORTANT: do NOT try to CREATE EXTENSION "ash-functions"
  end

  # def change do
  #   execute(~s(CREATE EXTENSION IF NOT EXISTS "citext";))
  #   execute(~s(CREATE EXTENSION IF NOT EXISTS "ash-functions";))
  # end
end
