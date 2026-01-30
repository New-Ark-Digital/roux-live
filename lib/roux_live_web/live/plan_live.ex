defmodule RouxLiveWeb.PlanLive do
  use RouxLiveWeb, :live_view
  alias RouxLive.Content.RecipeLoader

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  def handle_info({:plan_updated, plan}, socket) do
    plan_recipes = 
      plan
      |> Enum.map(&RecipeLoader.load!/1)

    {:noreply, assign(socket, :plan_recipes, plan_recipes)}
  end

  def render(assigns) do
    ~H"""
    <RouxLiveWeb.Layouts.app flash={@flash} plan_count={@plan_count}>
      <div class="font-body pt-32 pb-20">
        <header class="max-w-7xl mx-auto px-4 space-y-12">
          <div class="space-y-4">
            <h1 class="text-7xl sm:text-8xl font-display text-gray-900 leading-[0.9] tracking-tight">
              Meal <span class="text-coral italic underline decoration-parchment underline-offset-8">Plan</span>
            </h1>
            <p class="text-xl text-gray-600 max-w-xl">
              <%= if @plan_count > 0 do %>
                You have {@plan_count} <%= if @plan_count == 1, do: "recipe", else: "recipes" %> in your plan. Ready to cook?
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
              <p class="text-gray-500 text-lg">Add some recipes to your plan to see the deterministic timeline.</p>
              <.link navigate={~p"/recipes"} class="inline-block mt-8 px-8 py-4 bg-coral text-white font-bold rounded-full hover:scale-105 transition-transform active:scale-95">
                Browse Recipes
              </.link>
            </div>
          <% else %>
            <div class="grid grid-cols-1 lg:grid-cols-12 gap-12 items-start">
              <%!-- Recipe Queue --%>
              <div class="lg:col-span-4 space-y-8">
                <h2 class="text-xs font-bold text-gray-400 uppercase tracking-widest">Recipe Queue</h2>
                <div class="space-y-4">
                  <%= for recipe <- @plan_recipes do %>
                    <div class="group relative bg-white p-6 rounded-[32px] border border-parchment shadow-sm hover:shadow-xl transition-all duration-500 flex items-center gap-4">
                      <div class="size-16 rounded-2xl bg-coral flex items-center justify-center text-2xl font-display text-white shrink-0">
                        {String.at(recipe.title, 0)}
                      </div>
                      <div class="min-w-0 flex-1">
                        <h4 class="font-display text-lg text-gray-900 truncate">{recipe.title}</h4>
                        <p class="text-xs text-gray-500">{recipe.time.total_minutes}m • {length(recipe.ingredients)} ingredients</p>
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
                <.link navigate={~p"/recipes"} class="block w-full text-center py-4 bg-linen rounded-2xl font-body font-bold text-gray-600 hover:bg-parchment transition-colors">
                  Add More Recipes
                </.link>
              </div>

              <%!-- Timeline Orchestrator (Placeholder for now) --%>
              <div class="lg:col-span-8 space-y-8">
                <div class="flex items-center justify-between">
                  <h2 class="text-xs font-bold text-gray-400 uppercase tracking-widest">Orchestrated Timeline</h2>
                  <span class="px-3 py-1 bg-basil text-gray-600 text-[10px] font-bold uppercase tracking-widest rounded-full">
                    Deterministic v3
                  </span>
                </div>
                
                <div class="bg-cream p-12 rounded-[48px] border border-parchment space-y-12 min-h-[400px] flex flex-col items-center justify-center text-center">
                  <div class="size-20 bg-white rounded-full flex items-center justify-center shadow-xl mb-6">
                    <.icon name="hero-sparkles" class="size-10 text-coral" />
                  </div>
                  <div class="space-y-4 max-w-md">
                    <h3 class="text-3xl font-display text-gray-900">The Orchestrator is ready.</h3>
                    <p class="text-gray-500 leading-relaxed">
                      I've analyzed your {length(@plan_recipes)} recipes. Next, I'll merge their instructions into a single, phased workflow.
                    </p>
                  </div>
                  <button class="px-10 py-4 bg-gray-900 text-white font-bold rounded-full hover:bg-coral transition-all active:scale-95 shadow-2xl">
                    Generate Phase Flow &rarr;
                  </button>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </RouxLiveWeb.Layouts.app>
    """
  end
end
