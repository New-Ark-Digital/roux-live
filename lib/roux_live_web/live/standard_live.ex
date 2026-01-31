defmodule RouxLiveWeb.StandardLive do
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
     |> assign(:phases, nil)
     |> assign(:all_tasks, [])
     |> assign(:active_task_id, nil)
     |> assign(:active_tab, "all")
     |> assign(:page_title, "Cooking Mode")}
  end

  def handle_params(params, _url, socket) do
    {:noreply,
     assign(socket, :active_task_id, params["task_id"] || socket.assigns[:active_task_id])}
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

      # Calculate time offsets for progress tracking and update the phase lists
      {all_tasks_with_offsets, total_seconds} =
        Enum.reduce(all_tasks, {[], 0}, fn task, {acc, current_offset} ->
          duration = (task.work_m + task.wait_m) * 60
          {acc ++ [Map.put(task, :start_offset_s, current_offset)], current_offset + duration}
        end)

      # Create a lookup map for the enriched tasks
      task_lookup = Map.new(all_tasks_with_offsets, fn t -> {t.id, t} end)

      # Re-map phases to include the offset data
      updated_phases = %{
        phases
        | mise_en_place: Enum.map(phases.mise_en_place, &Map.get(task_lookup, &1.id)),
          long_lead: Enum.map(phases.long_lead, &Map.get(task_lookup, &1.id)),
          setup: Enum.map(phases.setup, &Map.get(task_lookup, &1.id)),
          action: Enum.map(phases.action, &Map.get(task_lookup, &1.id))
      }

      ingredients_by_id =
        recipes
        |> Enum.flat_map(& &1.ingredients)
        |> Enum.group_by(& &1.id)
        |> Map.new(fn {id, ing_list} -> {id, List.first(ing_list)} end)

      active_task_id =
        socket.assigns.active_task_id || (List.first(all_tasks) && List.first(all_tasks).id)

      {:noreply,
       socket
       |> assign(:recipes, recipes)
       |> assign(:phases, updated_phases)
       |> assign(:all_tasks, all_tasks_with_offsets)
       |> assign(:total_seconds, total_seconds)
       |> assign(:ingredients_by_id, ingredients_by_id)
       |> assign(:active_task_id, active_task_id)}
    end
  end

  def handle_event("select_task", %{"id" => id}, socket) do
    path =
      if socket.assigns.slug do
        ~p"/cook/#{socket.assigns.slug}/task/#{id}"
      else
        ~p"/cook/multi/task/#{id}"
      end

    {:noreply, push_patch(socket, to: path)}
  end

  def handle_event("select_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("finish_meal", _params, socket) do
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
    if is_nil(assigns.phases) do
      ~H"""
      <RouxLiveWeb.Layouts.app flash={@flash} plan_count={@plan_count}>
        <div class="h-screen bg-canvas flex flex-col items-center justify-center">
          <div class="size-20 bg-white rounded-full flex items-center justify-center shadow-xl mb-6 animate-pulse">
            <.icon name="hero-sparkles" class="size-10 text-coral" />
          </div>
          <h2 class="text-2xl font-display text-gray-900">Synchronizing Kitchen...</h2>
        </div>
      </RouxLiveWeb.Layouts.app>
      """
    else
      active_task =
        Enum.find(assigns.all_tasks, &(&1.id == assigns.active_task_id)) ||
          List.first(assigns.all_tasks)

      active_task_index =
        Enum.find_index(assigns.all_tasks, &(&1.id == assigns.active_task_id)) || 0

      progress =
        if assigns.total_seconds > 0 && active_task do
          active_task.start_offset_s / assigns.total_seconds * 100
        else
          0
        end

      highlighted_ids = (active_task && active_task.uses) || []

      active_ingredients =
        Enum.map(highlighted_ids, &Map.get(assigns.ingredients_by_id, &1))
        |> Enum.reject(&is_nil/1)

      assigns =
        assign(assigns,
          active_task: active_task,
          active_task_index: active_task_index,
          progress: progress,
          highlighted_ids: highlighted_ids,
          active_ingredients: active_ingredients
        )

      ~H"""
      <RouxLiveWeb.Layouts.app
        flash={@flash}
        active_ingredients={@active_ingredients}
        active_step_index={@active_task_index}
        hide_nav={true}
      >
        <.cooking_hero
          title={if @slug, do: List.first(@recipes).title, else: "Unified Meal Plan"}
          plan_count={@plan_count}
          active_ingredients={@active_ingredients}
          progress={@progress}
          remaining_text={
            if @total_seconds > 0 && @active_task do
              remaining = @total_seconds - @active_task.start_offset_s
              h = div(remaining, 3600)
              m = div(rem(remaining, 3600), 60)
              "#{if h > 0, do: "#{h}h ", else: ""}#{m}m left"
            end
          }
          mode="standard"
          slug={@slug}
          active_task_id={@active_task_id}
        />

        <div class="font-body pt-52 lg:pt-60 bg-canvas min-h-screen pb-32 lg:pb-0">
          <div class="max-w-7xl mx-auto px-4 grid grid-cols-1 lg:grid-cols-12 gap-12 items-stretch">
            <%!-- Sidebar: Ingredients --%>
            <div class="hidden lg:flex lg:col-span-4 flex-col gap-6 h-[calc(100vh-260px)] sticky top-60">
              <div class="bg-white p-8 rounded-[48px] border border-parchment flex flex-col min-h-0 flex-1 shadow-sm overflow-hidden">
                <div class="mb-6 flex justify-between items-center shrink-0">
                  <h3 class="text-xs font-bold text-gray-400 uppercase tracking-widest">
                    Kitchen Context
                  </h3>
                </div>

                <div
                  id="ingredients-scroll"
                  phx-hook="IngredientAutoScroll"
                  class="flex-1 overflow-y-auto custom-scrollbar space-y-10 px-4 pr-2"
                >
                  <%= for recipe <- @recipes do %>
                    <div class="space-y-6">
                      <div class="flex items-center gap-3 border-b border-linen pb-3">
                        <div class="size-6 rounded-lg bg-coral/10 text-coral flex items-center justify-center text-[10px] font-bold">
                          {String.at(recipe.title, 0)}
                        </div>
                        <h4 class="text-[10px] font-bold text-gray-900 uppercase tracking-widest">
                          {recipe.title}
                        </h4>
                      </div>
                      <ul class="space-y-3">
                        <%= for ing <- recipe.ingredients do %>
                          <.ingredient_item ingredient={ing} highlighted={ing.id in @highlighted_ids} />
                        <% end %>
                      </ul>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>

            <%!-- Main Timeline --%>
            <div class="lg:col-span-8 space-y-8">
              <%!-- Desktop Tab Navigation (Sticky) --%>
              <div
                :if={length(@recipes) > 1}
                class="hidden lg:flex sticky top-52 z-30 gap-2 p-1.5 bg-white/80 backdrop-blur rounded-[24px] border border-parchment shadow-lg"
              >
                <.tab_button
                  active?={@active_tab == "all"}
                  label="All Dishes"
                  phx-click="select_tab"
                  phx-value-tab="all"
                />
                <%= for recipe <- @recipes do %>
                  <.tab_button
                    active?={@active_tab == recipe.slug}
                    label={recipe.title}
                    phx-click="select_tab"
                    phx-value-tab={recipe.slug}
                  />
                <% end %>
              </div>

              <div class="space-y-16 pb-32">
                <%!-- Phases filtered by tab --%>
                <.render_phase
                  :if={should_show_phase?(@phases.mise_en_place, @active_tab)}
                  title="Phase 1: Mise en Place"
                  tasks={filter_tasks(@phases.mise_en_place, @active_tab)}
                  active_id={@active_task_id}
                  total_seconds={@total_seconds}
                  color="bg-basil"
                />

                <.render_phase
                  :if={should_show_phase?(@phases.long_lead, @active_tab)}
                  title="Phase 2: Long-Lead Prep"
                  tasks={filter_tasks(@phases.long_lead, @active_tab)}
                  active_id={@active_task_id}
                  total_seconds={@total_seconds}
                  color="bg-lavender"
                />

                <.render_phase
                  :if={should_show_phase?(@phases.setup, @active_tab)}
                  title="Phase 3: The Setup"
                  tasks={filter_tasks(@phases.setup, @active_tab)}
                  active_id={@active_task_id}
                  total_seconds={@total_seconds}
                  color="bg-egg-yolk"
                />

                <.render_phase
                  :if={should_show_phase?(@phases.action, @active_tab)}
                  title="Phase 4: Action"
                  tasks={filter_tasks(@phases.action, @active_tab)}
                  active_id={@active_task_id}
                  total_seconds={@total_seconds}
                  color="bg-coral"
                />

                <%!-- The "Done" Section --%>
                <div class="pt-16 border-t border-linen">
                  <div class="bg-gray-900 rounded-[48px] p-12 text-center space-y-8 shadow-2xl">
                    <div class="size-20 bg-white/10 rounded-full flex items-center justify-center mx-auto">
                      <.icon name="hero-check-badge" class="size-10 text-basil" />
                    </div>
                    <div class="space-y-4">
                      <h3 class="text-4xl font-display text-white italic">Dinner is served.</h3>
                      <p class="text-gray-400 max-w-sm mx-auto">
                        Everything is ready. Mark this meal as complete to clear your plan.
                      </p>
                    </div>
                    <button
                      phx-click="finish_meal"
                      class="px-12 py-5 bg-basil text-gray-900 font-bold rounded-full hover:scale-105 transition-all active:scale-95 shadow-xl"
                    >
                      Complete & Clear Plan
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </RouxLiveWeb.Layouts.app>
      """
    end
  end

  attr :active?, :boolean, required: true
  attr :label, :string, required: true
  attr :compact, :boolean, default: false
  attr :rest, :global

  defp tab_button(assigns) do
    ~H"""
    <button
      {@rest}
      class={[
        "rounded-full font-bold transition-all whitespace-nowrap border shrink-0",
        if(@compact, do: "px-4 py-2 text-[10px]", else: "px-6 py-3 text-xs"),
        if(@active?,
          do: "bg-gray-900 text-white border-gray-900 shadow-md",
          else:
            "bg-white text-gray-500 border-parchment hover:border-coral/50 hover:text-gray-700 shadow-sm"
        )
      ]}
    >
      {@label}
    </button>
    """
  end

  defp render_phase(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center gap-4">
        <h3 class="text-xs font-bold text-gray-400 uppercase tracking-[0.3em]">{@title}</h3>
        <div class="h-px bg-parchment flex-1"></div>
      </div>
      <div class="space-y-4">
        <%= for task <- @tasks do %>
          <div
            phx-click="select_task"
            phx-value-id={task.id}
            id={task.id}
            class={[
              "p-8 rounded-[32px] border transition-all cursor-pointer group relative overflow-hidden",
              if(@active_id == task.id,
                do: "bg-white border-coral shadow-2xl -translate-y-1",
                else: "bg-white/50 border-parchment hover:border-coral/30"
              )
            ]}
          >
            <div :if={@active_id == task.id} class={["absolute left-0 top-0 bottom-0 w-1.5", @color]}>
            </div>

            <div class="flex gap-6 items-start">
              <div class="space-y-2 flex-1">
                <div class="flex justify-between items-center mb-2">
                  <span class="text-[10px] font-bold text-gray-400 uppercase tracking-widest">
                    {task.recipe_title}
                  </span>
                  <div class="flex gap-2">
                    <span
                      :if={task.work_m > 0}
                      class="px-2 py-0.5 bg-linen text-gray-500 text-[10px] font-bold rounded"
                    >
                      {task.work_m}m Active
                    </span>
                    <span
                      :if={task.wait_m > 0}
                      class="px-2 py-0.5 bg-linen text-gray-500 text-[10px] font-bold rounded uppercase"
                    >
                      {task.wait_m}m {if task.wait_details, do: task.wait_details.kind, else: "Wait"}
                    </span>
                  </div>
                </div>
                <p class={[
                  "text-xl leading-snug transition-colors",
                  if(@active_id == task.id, do: "text-gray-900 font-medium", else: "text-gray-500")
                ]}>
                  {task.text}
                </p>

                <%!-- Timer Integration for Active Task --%>
                <div
                  :if={
                    @active_id == task.id && needs_timer?(task.text) &&
                      (task.work_m > 0 || task.wait_m > 0)
                  }
                  id={"timer-#{task.id}"}
                  phx-hook="CookingTimer"
                  data-work={task.work_m}
                  data-wait={task.wait_m}
                  data-offset={task.start_offset_s}
                  data-total={assigns.total_seconds}
                  class="mt-6 bg-linen/50 rounded-2xl p-6 flex items-center justify-between group"
                >
                  <div class="flex flex-col">
                    <span class="text-[9px] font-bold text-gray-400 uppercase tracking-widest mb-1">
                      Live Timer
                    </span>
                    <div class="text-3xl font-display text-gray-900 tabular-nums" id="timer-display">
                      {if task.work_m > 0, do: task.work_m, else: task.wait_m}:00
                    </div>
                  </div>
                  <button
                    id="timer-toggle"
                    class="size-12 rounded-full bg-gray-900 text-white flex items-center justify-center hover:bg-coral transition-all active:scale-95 shadow-lg"
                  >
                    <.icon name="hero-play" class="size-6" id="timer-icon" />
                  </button>
                </div>

                <div
                  :if={task.type == "terminal" && @active_id == task.id}
                  class="mt-6 pt-6 border-t border-linen flex justify-center"
                >
                  <button
                    phx-click="finish_meal"
                    class="px-8 py-3 bg-basil text-gray-900 font-bold rounded-2xl hover:scale-105 transition-all active:scale-95 shadow-lg flex items-center gap-2"
                  >
                    <.icon name="hero-check-circle" class="size-5" /> Finish Recipe & Clear Plan
                  </button>
                </div>

                <%!-- Prep Breakdown for Unified Items --%>
                <div
                  :if={task.prep_breakdown && @active_id == task.id}
                  class="mt-4 grid grid-cols-2 gap-4 pt-4 border-t border-linen"
                >
                  <%= for {title, details} <- task.prep_breakdown do %>
                    <div>
                      <span class="block text-[9px] font-bold text-gray-400 uppercase tracking-tighter">
                        {title}
                      </span>
                      <span class="text-sm font-bold text-gray-700">{details}</span>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp ingredient_item(assigns) do
    ~H"""
    <li
      data-highlighted={to_string(@highlighted)}
      class={[
        "flex justify-between items-baseline gap-4 p-3 rounded-xl transition-all",
        if(@highlighted,
          do: "bg-linen border border-parchment shadow-sm border-l-4 border-l-coral pl-4",
          else: "opacity-40 grayscale"
        )
      ]}
    >
      <span class="text-lg font-bold text-gray-900 leading-tight">{@ingredient.name}</span>
      <span class="text-sm font-bold text-gray-400 whitespace-nowrap">
        {@ingredient.amount} {@ingredient.unit}
      </span>
    </li>
    """
  end

  defp filter_tasks(tasks, "all"), do: tasks

  defp filter_tasks(tasks, tab_slug) do
    Enum.filter(tasks, fn t ->
      t.recipe_slug == tab_slug ||
        (t.prep_breakdown && Map.has_key?(t.prep_breakdown, get_title_by_slug(tab_slug)))
    end)
  end

  defp should_show_phase?(tasks, tab) do
    filter_tasks(tasks, tab) != []
  end

  defp get_title_by_slug(slug) do
    # This is a bit expensive but fine for MVP
    RouxLive.Content.RecipeLoader.load!(slug).title
  end

  defp needs_timer?(text) do
    Regex.run(~r/\d+\s*(mins?|minutes?|seconds?|hours?)/i, text) != nil
  end
end
