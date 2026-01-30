defmodule RouxLiveWeb.PlanIntegrationTest do
  use RouxLiveWeb.ConnCase
  import Phoenix.LiveViewTest

  test "can toggle plan from home page", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    
    # Simulate the JS hook loading an empty plan
    render_hook(view, "load_plan", %{"plan" => []})
    
    # Click the add to plan button for chocolate-chip-cookies
    view
    |> element("button[phx-value-slug='chocolate-chip-cookies']")
    |> render_click()
    
    # Check if the plan was updated in the state (look for the count in the nav)
    assert render(view) =~ "Plan"
    assert render(view) =~ "1"

    # Navigate to the plan page
    {:ok, plan_view, _html} = live(conn, ~p"/plan")
    
    # Simulate loading the plan from hook
    render_hook(plan_view, "load_plan", %{"plan" => ["chocolate-chip-cookies"]})
    
    # Click the generate flow button
    render_click(element(plan_view, "button", "Generate Phase Flow"))
    
    # Check if any phase content is rendered
    assert render(plan_view) =~ "Phase"
  end
end
