defmodule RouxLiveWeb.PlanLive do
  use RouxLiveWeb, :live_view
  alias RouxLive.Content.RecipeLoader

  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:plan_recipes, [])
     |> assign(:phases, nil)
     |> assign(:kitchen_type, "standard")
     |> assign(:url_recipes, params["recipes"])
     |> assign(:show_conflict_modal, false)}
  end

  def handle_params(_params, _url, socket) do
    # recipes=slug1,slug2
    {:noreply, socket}
  end

  def handle_event("select_kitchen", %{"type" => type}, socket) do
    {:noreply, assign(socket, :kitchen_type, type)}
  end

  def handle_event("use_url_plan", _params, socket) do
    slugs = String.split(socket.assigns.url_recipes, ",")
    new_plan = slugs |> Enum.uniq()

    socket =
      socket
      |> assign(:show_conflict_modal, false)
      |> push_event("save_plan", %{plan: new_plan})

    # Trigger a reload of plan_recipes
    send(self(), {:plan_updated, new_plan})

    {:noreply, socket}
  end

  def handle_event("keep_local_plan", _params, socket) do
    # Just clear the modal and sync the URL to current plan
    {:noreply,
     socket
     |> assign(:show_conflict_modal, false)
     |> sync_url_plan(socket.assigns.plan)}
  end

  def handle_event("generate_flow", _params, socket) do
    phases =
      RouxLive.Orchestrator.generate_phases(
        socket.assigns.plan_recipes,
        socket.assigns.kitchen_type
      )

    {:noreply, assign(socket, :phases, phases)}
  end

  def handle_info({:plan_updated, plan}, socket) do
    plan_recipes =
      plan
      |> Enum.map(&RecipeLoader.load!/1)

    # Check for conflict if url_recipes is present
    show_modal =
      if socket.assigns.url_recipes do
        url_slugs = socket.assigns.url_recipes |> String.split(",") |> Enum.sort()
        local_slugs = plan |> Enum.sort()
        url_slugs != local_slugs
      else
        false
      end

    socket =
      socket
      |> assign(:plan_recipes, plan_recipes)
      |> assign(:phases, nil)
      |> assign(:show_conflict_modal, show_modal)

    # If no conflict, or after resolving, we should update the URL if plan changes
    # but only if url_recipes was not just set.
    socket =
      if !show_modal do
        sync_url_plan(socket, plan)
      else
        socket
      end

    {:noreply, socket}
  end

  defp sync_url_plan(socket, plan) do
    if plan == [] do
      push_patch(socket, to: ~p"/plan")
    else
      recipes_str = Enum.join(plan, ",")
      push_patch(socket, to: ~p"/plan?recipes=#{recipes_str}")
    end
  end

  def render(assigns) do
    ~H"""
    <RouxLiveWeb.Layouts.app flash={@flash} plan_count={@plan_count}>
      <%!-- Conflict Modal --%>
      <div
        :if={@show_conflict_modal}
        class="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-gray-900/60 backdrop-blur-sm"
      >
        <div class="bg-white rounded-[40px] p-10 max-w-lg w-full shadow-2xl space-y-8 animate-in zoom-in duration-300">
          <div class="size-16 bg-coral/10 rounded-2xl flex items-center justify-center">
            <.icon name="hero-arrows-right-left" class="size-8 text-coral" />
          </div>
          <div class="space-y-2">
            <h3 class="text-3xl font-display text-gray-900 leading-tight">Plan Mismatch</h3>
            <p class="text-gray-500 leading-relaxed">
              The link you opened has different recipes than your current plan. Which one would you like to use?
            </p>
          </div>
          <div class="flex flex-col sm:flex-row gap-4">
            <button
              phx-click="use_url_plan"
              class="flex-1 py-4 bg-gray-900 text-white font-bold rounded-2xl hover:bg-coral transition-all active:scale-95 shadow-lg"
            >
              Use Link Plan
            </button>
            <button
              phx-click="keep_local_plan"
              class="flex-1 py-4 bg-linen text-gray-600 font-bold rounded-2xl hover:bg-parchment transition-all active:scale-95"
            >
              Keep My Plan
            </button>
          </div>
        </div>
      </div>

      <div class="font-body pt-32 pb-20">
        <header class="max-w-7xl mx-auto px-4 space-y-12">
          <div class="space-y-4">
            <h1 class="text-7xl sm:text-8xl font-display text-gray-900 leading-[0.9] tracking-tight">
              Meal
              <span class="text-coral italic underline decoration-parchment underline-offset-8">
                Plan
              </span>
            </h1>
            <p class="text-xl text-gray-600 max-w-xl">
              <%= if @plan_count > 0 do %>
                You have {@plan_count} {if @plan_count == 1, do: "recipe", else: "recipes"} in your plan. Ready to cook?
              <% else %>
                Your plan is empty. Browse recipes to get started.
              <% end %>
            </p>
          </div>
        </header>

        <div class="max-w-7xl mx-auto px-4 mt-20">
          <%= if @plan_count == 0 do %>
            <div class="text-center py-32 bg-linen rounded-[48px] border-2 border-dashed border-parchment">
              <div class="text-6xl mb-6">🗓️</div>
              <h3 class="text-3xl font-display text-gray-900">No recipes selected</h3>
              <p class="text-gray-500 text-lg">
                Add some recipes to your plan to see the deterministic timeline.
              </p>
              <.link
                navigate={~p"/recipes"}
                class="inline-block mt-8 px-8 py-4 bg-coral text-white font-bold rounded-full hover:scale-105 transition-transform active:scale-95"
              >
                Browse Recipes
              </.link>
            </div>
          <% else %>
            <div class="grid grid-cols-1 lg:grid-cols-12 gap-12 items-start">
              <%!-- Recipe Queue --%>
              <div class="lg:col-span-4 space-y-8">
                <h2 class="text-xs font-bold text-gray-400 uppercase tracking-widest">
                  Recipe Queue
                </h2>
                <div class="space-y-4">
                  <%= for recipe <- @plan_recipes do %>
                    <div class="group relative bg-white p-6 rounded-[32px] border border-parchment shadow-sm hover:shadow-xl transition-all duration-500 flex items-center gap-4">
                      <div class="size-16 rounded-2xl bg-coral flex items-center justify-center text-2xl font-display text-white shrink-0">
                        {String.at(recipe.title, 0)}
                      </div>
                      <div class="min-w-0 flex-1">
                        <h4 class="font-display text-lg text-gray-900 truncate">{recipe.title}</h4>
                        <p class="text-xs text-gray-500">
                          {recipe.time.total_minutes}m • {length(recipe.ingredients)} ingredients
                        </p>
                      </div>
                      <button
                        phx-click="toggle_plan"
                        phx-value-slug={recipe.slug}
                        class="size-8 rounded-full bg-linen text-gray-400 hover:bg-red/10 hover:text-red transition-colors flex items-center justify-center"
                      >
                        <.icon name="hero-x-mark" class="size-4" />
                      </button>
                    </div>
                  <% end %>
                </div>
                <.link
                  navigate={~p"/recipes"}
                  class="block w-full text-center py-4 bg-linen rounded-2xl font-body font-bold text-gray-600 hover:bg-parchment transition-colors"
                >
                  Add More Recipes
                </.link>
              </div>

              <%!-- Timeline Orchestrator --%>
              <div class="lg:col-span-8 space-y-8">
                <div class="flex items-center justify-between">
                  <h2 class="text-xs font-bold text-gray-400 uppercase tracking-widest">
                    Orchestrated Timeline
                  </h2>
                  <div class="flex gap-2">
                    <span
                      :if={@phases && @phases.warnings != []}
                      class="px-3 py-1 bg-red/10 text-red text-[10px] font-bold uppercase tracking-widest rounded-full animate-pulse"
                    >
                      Resource Conflict
                    </span>
                    <span class="px-3 py-1 bg-basil text-gray-600 text-[10px] font-bold uppercase tracking-widest rounded-full">
                      Deterministic v6
                    </span>
                  </div>
                </div>

                <%= if is_nil(@phases) do %>
                  <div class="bg-cream p-12 rounded-[48px] border border-parchment space-y-12 min-h-[400px] flex flex-col items-center justify-center text-center">
                    <div class="size-20 bg-white rounded-full flex items-center justify-center shadow-xl mb-6">
                      <.icon name="hero-sparkles" class="size-10 text-coral" />
                    </div>
                    <div class="space-y-4 max-w-md">
                      <h3 class="text-3xl font-display text-gray-900">The Orchestrator is ready.</h3>
                      <p class="text-gray-500 leading-relaxed">
                        I've analyzed your {length(@plan_recipes)} recipes. Next, choose your kitchen setup and I'll build your workflow.
                      </p>
                    </div>

                    <%!-- Kitchen Profile Selector --%>
                    <div class="space-y-4 flex flex-col items-center">
                      <div class="flex p-1 bg-linen rounded-full border border-parchment">
                        <%= for {type, label} <- [{"minimalist", "Minimalist"}, {"standard", "Standard"}, {"chef", "Chef"}] do %>
                          <button
                            phx-click="select_kitchen"
                            phx-value-type={type}
                            class={[
                              "px-6 py-2 rounded-full text-xs font-bold transition-all",
                              if(@kitchen_type == type,
                                do: "bg-gray-900 text-white shadow-lg",
                                else: "text-gray-400 hover:text-gray-600"
                              )
                            ]}
                          >
                            {label}
                          </button>
                        <% end %>
                      </div>

                      <p class="text-xs text-gray-400 font-medium italic">
                        <%= case @kitchen_type do %>
                          <% "minimalist" -> %>
                            2 Burners, 1 Oven, 1 Prep Area
                          <% "standard" -> %>
                            4 Burners, 1 Oven, 2 Prep Areas
                          <% "chef" -> %>
                            6 Burners, Double Oven, Prep Island
                        <% end %>
                      </p>
                    </div>

                    <button
                      phx-click="generate_flow"
                      class="px-10 py-4 bg-gray-900 text-white font-bold rounded-full hover:bg-coral transition-all active:scale-95 shadow-2xl cursor-pointer"
                    >
                      Generate Phase Flow &rarr;
                    </button>
                  </div>
                <% else %>
                  <div class="space-y-12 pb-24">
                    <%!-- Start Cooking Call to Action --%>
                    <div class="bg-gray-900 p-8 rounded-[40px] flex flex-col md:flex-row items-center justify-between gap-6 shadow-2xl">
                      <div class="space-y-1 text-center md:text-left">
                        <h3 class="text-2xl font-display text-white">Ready to cook?</h3>
                        <p class="text-gray-400 text-sm">
                          Everything is orchestrated. Let's start the run.
                        </p>
                      </div>
                      <.link
                        navigate={~p"/cook"}
                        class="px-12 py-4 bg-coral text-white font-bold rounded-full hover:bg-red hover:scale-105 transition-all active:scale-95 shadow-xl"
                      >
                        Start Meal Run &rarr;
                      </.link>
                    </div>

                    <%!-- Warnings Area --%>
                    <div
                      :if={@phases.warnings != []}
                      class="bg-red/5 border border-red/20 p-6 rounded-[32px] space-y-3"
                    >
                      <%= for warning <- @phases.warnings do %>
                        <p class="text-sm text-red-600 font-bold flex items-center gap-2">
                          <span class="size-2 rounded-full bg-red animate-pulse"></span>
                          {warning}
                        </p>
                      <% end %>
                    </div>

                    <%!-- Phase 1: Mise en Place --%>
                    <.phase_section
                      :if={@phases.mise_en_place != []}
                      title="Phase 1: Mise en Place"
                      subtitle="All dicing, mincing, and measuring. Get this done first!"
                      tasks={@phases.mise_en_place}
                      color="bg-basil"
                    />

                    <%!-- Phase 2: Long-Lead --%>
                    <.phase_section
                      :if={@phases.long_lead != []}
                      title="Phase 2: Long-Lead Prep"
                      subtitle="Steps that need to start now to wait later (doughs, marinades)."
                      tasks={@phases.long_lead}
                      color="bg-lavender"
                    />

                    <%!-- Phase 3: Setup --%>
                    <.phase_section
                      :if={@phases.setup != []}
                      title="Phase 3: The Setup"
                      subtitle="Preheating ovens and boiling water."
                      tasks={@phases.setup}
                      color="bg-egg-yolk"
                    />

                    <%!-- Phase 4: Action --%>
                    <.phase_section
                      :if={@phases.action != []}
                      title="Phase 4: Action"
                      subtitle="The cooking process. Follow the order for perfect timing."
                      tasks={@phases.action}
                      color="bg-pink"
                    />
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </RouxLiveWeb.Layouts.app>
    """
  end

  def phase_section(assigns) do
    ~H"""
    <div class="space-y-6 animate-in slide-in-from-bottom-4 duration-700">
      <div class="flex items-end justify-between border-b border-parchment pb-4">
        <div class="space-y-1">
          <h3 class="text-2xl font-display text-gray-900">{@title}</h3>
          <p class="text-sm text-gray-500">{@subtitle}</p>
        </div>
        <span class={[
          "px-3 py-1 rounded-full text-[10px] font-bold uppercase tracking-widest",
          @color
        ]}>
          {length(@tasks)} Tasks
        </span>
      </div>

      <div class="grid grid-cols-1 gap-4">
        <%= for task <- @tasks do %>
          <div class={[
            "p-6 rounded-3xl border transition-all flex items-start gap-6 group hover:border-coral",
            if(task.is_utility,
              do: "bg-linen/30 border-dashed border-gray-300 opacity-70",
              else: "bg-white border-parchment shadow-sm"
            ),
            task.type == "terminal" && "border-dashed opacity-80"
          ]}>
            <div class="flex-none pt-1">
              <div class={[
                "size-6 rounded-lg border-2 flex items-center justify-center transition-colors",
                if(task.is_utility,
                  do: "border-gray-300",
                  else: "border-parchment group-hover:border-coral"
                )
              ]}>
                <div class="size-3 bg-coral rounded-sm scale-0 group-hover:scale-100 transition-transform">
                </div>
              </div>
            </div>
            <div class="space-y-2 flex-1">
              <div class="flex justify-between items-start">
                <span class="text-[10px] font-bold text-gray-400 uppercase tracking-widest leading-none block">
                  {task.recipe_title}
                </span>
                <span
                  :if={task.start_at_m != nil}
                  class="text-[10px] font-bold text-coral bg-linen px-2 py-0.5 rounded-full"
                >
                  T +{task.start_at_m}m
                </span>
              </div>
              <p class={[
                "text-lg leading-tight",
                if(task.is_utility, do: "text-gray-500 italic font-medium", else: "text-gray-700")
              ]}>
                {task.text}
              </p>
              <div class="flex gap-4">
                <span
                  :if={task.work_m > 0}
                  class="text-[9px] font-bold text-gray-400 uppercase bg-linen px-2 py-0.5 rounded-md"
                >
                  Active: {task.work_m}m
                </span>
                <span
                  :if={task.wait_m > 0}
                  class="text-[9px] font-bold text-gray-400 uppercase bg-linen px-2 py-0.5 rounded-md"
                >
                  <%= if task.wait_details do %>
                    {task.wait_details.kind}: {task.wait_m}m
                  <% else %>
                    Wait: {task.wait_m}m
                  <% end %>
                </span>
                <span
                  :if={is_list(task.resources) and task.resources != []}
                  class="text-[9px] font-bold text-orange-400 uppercase bg-orange/5 px-2 py-0.5 rounded-md border border-orange/10"
                >
                  {Enum.join(task.resources, ", ")}
                </span>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
