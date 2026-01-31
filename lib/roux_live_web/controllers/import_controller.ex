defmodule RouxLiveWeb.ImportController do
  use RouxLiveWeb, :controller

  def create(conn, %{"url" => url}) do
    # Mock AI Compilation process
    # In a real app, this would fetch the URL and use an LLM to generate YAML

    recipe_id = "imported-#{DateTime.utc_now() |> DateTime.to_unix()}"

    json(conn, %{
      id: recipe_id,
      url: url,
      title: "Imported Recipe from #{URI.parse(url).host}",
      status: "compiled"
    })
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing url parameter"})
  end
end
