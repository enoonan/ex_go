defmodule ExGoWeb.PageController do
  use ExGoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
