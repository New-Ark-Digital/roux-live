defmodule RouxLiveWeb.PlanHelpers do
  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    socket = 
      socket 
      |> assign(:plan, []) 
      |> assign(:plan_count, 0)
      |> assign(:active_step_index, nil)
      |> assign(:active_ingredients, [])
      |> attach_hook(:plan_events, :handle_event, &handle_event/3)

    {:cont, socket}
  end

  def handle_event("load_plan", %{"plan" => plan}, socket) do
    IO.puts "DEBUG: Received load_plan with #{inspect(plan)}"
    socket =
     socket 
     |> assign(:plan, plan) 
     |> assign(:plan_count, length(plan))

    send(self(), {:plan_updated, plan})

    {:halt, socket}
  end

  def handle_event("toggle_plan", %{"slug" => slug}, socket) do
    IO.puts "DEBUG: Received toggle_plan for #{slug}"
    new_plan = 
      if slug in socket.assigns.plan do
        List.delete(socket.assigns.plan, slug)
      else
        [slug | socket.assigns.plan]
      end

    socket =
     socket
     |> assign(:plan, new_plan)
     |> assign(:plan_count, length(new_plan))
     |> push_event("save_plan", %{plan: new_plan})

    send(self(), {:plan_updated, new_plan})

    {:halt, socket}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}
end
