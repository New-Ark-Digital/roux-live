defmodule RouxLiveWeb.FocusLive do
  use RouxLiveWeb, :live_view
  alias RouxLive.Content.RecipeLoader
  alias RouxLive.Orchestrator

  def mount(params, _session, socket) do
    # Support for single recipes via slug or full plan
    slug = params["slug"]

    {:ok,
     socket
     |> assign(:slug, slug)
     |> assign(:recipes, [])
     |> assign(:all_tasks, nil)
     |> assign(:current_task_index, 0)
     |> assign(:ingredients_by_id, %{})
     |> assign(:timer_running, false)
     |> assign(:timer_seconds, 0)
     |> assign(:page_title, "Focus Mode")}
  end

  def handle_params(params, _url, socket) do
    task_id = params["task_id"]

    socket =
      if task_id && socket.assigns.all_tasks do
        index = Enum.find_index(socket.assigns.all_tasks, &(&1.id == task_id)) || 0
        assign(socket, :current_task_index, index)
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info({:plan_updated, plan}, socket) do
    plan_to_load = if socket.assigns.slug, do: [socket.assigns.slug], else: plan

    if plan_to_load == [] do
      {:noreply, push_navigate(socket, to: ~p"/plan")}
    else
      recipes = Enum.map(plan_to_load, &RecipeLoader.load!/1)
      phases = Orchestrator.generate_phases(recipes, "standard")

      all_tasks =
        phases.mise_en_place ++
          phases.long_lead ++
          phases.setup ++
          phases.action

      # Calculate time offsets for progress tracking
      {all_tasks_with_offsets, total_seconds} =
        Enum.reduce(all_tasks, {[], 0}, fn task, {acc, current_offset} ->
          duration = (task.work_m + task.wait_m) * 60
          {acc ++ [Map.put(task, :start_offset_s, current_offset)], current_offset + duration}
        end)

      ingredients_by_id =
        recipes
        |> Enum.flat_map(& &1.ingredients)
        |> Enum.group_by(& &1.id)
        |> Map.new(fn {id, ing_list} -> {id, List.first(ing_list)} end)

      # Handle initial deep link after tasks are loaded
      current_task_index =
        if task_id = socket.assigns.live_action == :index && socket.assigns[:task_id] do
          Enum.find_index(all_tasks_with_offsets, &(&1.id == task_id)) || 0
        else
          0
        end

      {:noreply,
       socket
       |> assign(:recipes, recipes)
       |> assign(:all_tasks, all_tasks_with_offsets)
       |> assign(:total_seconds, total_seconds)
       |> assign(:ingredients_by_id, ingredients_by_id)
       |> assign(:current_task_index, current_task_index)}
    end
  end

  def handle_event("next_task", _params, socket) do
    next_index = min(socket.assigns.current_task_index + 1, length(socket.assigns.all_tasks) - 1)
    task = Enum.at(socket.assigns.all_tasks, next_index)

    path =
      if socket.assigns.slug do
        ~p"/run/#{socket.assigns.slug}/task/#{task.id}"
      else
        ~p"/run/multi/task/#{task.id}"
      end

    {:noreply, push_patch(socket, to: path)}
  end

  def handle_event("prev_task", _params, socket) do
    prev_index = max(socket.assigns.current_task_index - 1, 0)
    task = Enum.at(socket.assigns.all_tasks, prev_index)

    path =
      if socket.assigns.slug do
        ~p"/run/#{socket.assigns.slug}/task/#{task.id}"
      else
        ~p"/run/multi/task/#{task.id}"
      end

    {:noreply, push_patch(socket, to: path)}
  end

  def handle_event("finish", _params, socket) do
    slugs = Enum.map(socket.assigns.recipes, & &1.slug)
    new_plan = Enum.reject(socket.assigns.plan, &(&1 in slugs))

    {:noreply,
     socket
     |> assign(:plan, new_plan)
     |> assign(:plan_count, length(new_plan))
     |> push_event("save_plan", %{plan: new_plan})
     |> put_flash(:info, "Meal complete! Recipes removed from your plan.")
     |> push_navigate(to: ~p"/")}
  end

  def render(assigns) do
    assigns =
      if assigns.all_tasks do
        current_task = Enum.at(assigns.all_tasks, assigns.current_task_index)

        active_ingredients =
          Enum.map(current_task.uses, &Map.get(assigns.ingredients_by_id, &1))
          |> Enum.reject(&is_nil/1)

        assign(assigns, current_task: current_task, active_ingredients: active_ingredients)
      else
        assign(assigns, current_task: nil, active_ingredients: [])
      end

    ~H"""
    <RouxLiveWeb.Layouts.app
      flash={@flash}
      active_ingredients={@active_ingredients}
      active_step_index={@current_task_index}
      hide_nav={true}
    >
      <%= if is_nil(@all_tasks) do %>
        <div class="h-screen bg-canvas flex flex-col items-center justify-center pt-24">
          <div class="size-20 bg-white rounded-full flex items-center justify-center shadow-xl mb-6 animate-pulse">
            <.icon name="hero-sparkles" class="size-10 text-coral" />
          </div>
          <h2 class="text-2xl font-display text-gray-900">Synchronizing Kitchen...</h2>
        </div>
      <% else %>
        <% total_tasks = length(@all_tasks)

        progress =
          if @total_seconds > 0 do
            @current_task.start_offset_s / @total_seconds * 100
          else
            0
          end %>
        <div class="h-screen bg-canvas flex flex-col pt-52 sm:pt-60 overflow-hidden">
          <.cooking_hero
            title={if @slug, do: List.first(@recipes).title, else: "Unified Meal Plan"}
            plan_count={@plan_count}
            active_ingredients={@active_ingredients}
            progress={progress}
            remaining_text={
              if @total_seconds > 0 do
                remaining = @total_seconds - @current_task.start_offset_s
                h = div(remaining, 3600)
                m = div(rem(remaining, 3600), 60)
                "#{if h > 0, do: "#{h}h ", else: ""}#{m}m left"
              end
            }
            mode="focus"
            slug={@slug}
            active_task_id={@current_task.id}
          />

          <div class="flex-1 max-w-2xl mx-auto w-full flex flex-col px-6 pb-12 overflow-y-auto custom-scrollbar">
            <%!-- Phase Indicator --%>
            <div class="flex items-center gap-3 mb-8 shrink-0">
              <span class="px-3 py-1 bg-gray-900 text-white text-[10px] font-bold uppercase tracking-[0.2em] rounded-full">
                {@current_task.phase || "Action"}
              </span>
              <span class="text-gray-400 text-[10px] font-bold uppercase tracking-widest">
                Task {@current_task_index + 1} of {total_tasks}
              </span>
            </div>

            <%!-- Main Instruction Card --%>
            <div class="flex-1 flex flex-col min-h-0 mb-8">
              <div class="bg-white rounded-[48px] p-10 border border-parchment shadow-2xl shadow-coral/5 space-y-8 flex-1 flex flex-col justify-center overflow-y-auto no-scrollbar">
                <div class="space-y-4 text-center">
                  <span class="text-xs font-bold text-coral uppercase tracking-widest">
                    {@current_task.recipe_title}
                  </span>
                  <h2 class={[
                    "font-display text-gray-900 leading-[1.1]",
                    instruction_size(@current_task.text)
                  ]}>
                    {@current_task.text}
                  </h2>
                </div>

                <%!-- Timer Integration Placeholder --%>
                <div
                  :if={
                    needs_timer?(@current_task.text) &&
                      (@current_task.work_m > 0 or @current_task.wait_m > 0)
                  }
                  id="task-timer"
                  phx-hook="CookingTimer"
                  data-work={@current_task.work_m}
                  data-wait={@current_task.wait_m}
                  data-offset={@current_task.start_offset_s}
                  data-total={@total_seconds}
                  class="bg-linen/50 rounded-3xl p-8 flex items-center justify-between group"
                >
                  <div class="flex flex-col">
                    <span class="text-[10px] font-bold text-gray-400 uppercase tracking-widest mb-1">
                      Timer
                    </span>
                    <div class="text-5xl font-display text-gray-900 tabular-nums" id="timer-display">
                      {if @current_task.work_m > 0,
                        do: @current_task.work_m,
                        else: @current_task.wait_m}:00
                    </div>
                  </div>
                  <button
                    id="timer-toggle"
                    class="size-16 rounded-full bg-gray-900 text-white flex items-center justify-center hover:bg-coral transition-all active:scale-95 shadow-xl"
                  >
                    <.icon name="hero-play" class="size-8" id="timer-icon" />
                  </button>
                </div>

                <%!-- Context: Ingredients & Equipment --%>
                <div class="space-y-6 pt-8 border-t border-linen">
                  <div :if={@current_task.uses != []} class="space-y-3">
                    <h3 class="text-[10px] font-bold text-gray-400 uppercase tracking-widest text-center">
                      Ingredients Needed
                    </h3>
                    <div class="flex flex-wrap justify-center gap-2">
                      <%= for id <- @current_task.uses do %>
                        <% ing = Map.get(@ingredients_by_id, id) %>
                        <div
                          :if={ing}
                          class="bg-white border border-parchment px-4 py-2 rounded-2xl flex items-center gap-3"
                        >
                          <span class="text-sm font-bold text-gray-900">{ing.name}</span>
                          <span class="text-xs text-coral font-bold">{ing.amount} {ing.unit}</span>
                        </div>
                      <% end %>
                    </div>
                  </div>

                  <div :if={@current_task.resources != []} class="space-y-3">
                    <h3 class="text-[10px] font-bold text-gray-400 uppercase tracking-widest text-center">
                      Equipment
                    </h3>
                    <div class="flex flex-wrap justify-center gap-2">
                      <%= for resource <- @current_task.resources do %>
                        <div class="bg-white border border-orange/20 px-4 py-2 rounded-2xl flex items-center gap-2">
                          <span class="size-1.5 rounded-full bg-orange-400"></span>
                          <span class="text-xs font-bold text-orange-400 uppercase tracking-tight">
                            {resource}
                          </span>
                        </div>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            </div>

            <%!-- Navigation Footer (Sticky-ish) --%>
            <div class="flex gap-4 shrink-0 pb-12">
              <button
                phx-click="prev_task"
                disabled={@current_task_index == 0}
                class="flex-1 py-6 bg-white border border-parchment rounded-3xl font-body font-bold text-gray-500 hover:bg-linen transition-colors disabled:opacity-30"
              >
                Back
              </button>
              <%= if @current_task_index == total_tasks - 1 do %>
                <button
                  phx-click="finish"
                  class="flex-[2] py-6 bg-basil text-gray-900 border border-gray-900/10 rounded-3xl font-body font-bold hover:scale-105 transition-all active:scale-95 shadow-xl"
                >
                  Complete Meal Run
                </button>
              <% else %>
                <button
                  phx-click="next_task"
                  class="flex-[2] py-6 bg-gray-900 text-white rounded-3xl font-body font-bold hover:bg-coral transition-all active:scale-95 shadow-xl"
                >
                  Next Step &rarr;
                </button>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </RouxLiveWeb.Layouts.app>
    """
  end

  defp needs_timer?(text) do
    Regex.run(~r/\d+\s*(mins?|minutes?|seconds?|hours?)/i, text) != nil
  end

  defp instruction_size(text) do
    len = String.length(text)

    cond do
      len < 60 -> "text-4xl sm:text-5xl"
      len < 120 -> "text-3xl sm:text-4xl"
      true -> "text-2xl sm:text-3xl"
    end
  end
end
