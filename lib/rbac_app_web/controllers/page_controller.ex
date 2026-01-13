defmodule RbacAppWeb.PageController do
  use RbacAppWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
