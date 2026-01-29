defmodule RouxLiveWeb.HomeLive do
  use RouxLiveWeb, :live_view
  alias RouxLive.Content.RecipeLoader

  def mount(_params, _session, socket) do
    recipes = RecipeLoader.list_all()
    featured = Enum.find(recipes, &(&1.slug == "chocolate-chip-cookies")) || List.first(recipes)
    
    # Get unique tags for the "Quick Tags" section
    tags = 
      recipes 
      |> Enum.flat_map(& &1.tags) 
      |> Enum.uniq() 
      |> Enum.sort()

    {:ok, 
     socket 
     |> assign(:recipes, recipes) 
     |> assign(:featured, featured) 
     |> assign(:tags, tags)
     |> assign(:search_query, "")}
  end

  def render(assigns) do
    ~H"""
    <RouxLiveWeb.Layouts.app flash={@flash}>
      <div class="font-body">
        <%!-- Hero Section --%>
        <section class="bg-white pt-32 pb-20 px-4">
          <div class="max-w-7xl mx-auto space-y-12">
            <div class="relative overflow-hidden rounded-[48px] bg-cream border border-parchment mesh-gradient p-8 sm:p-16 lg:p-24 min-h-[600px] flex items-center justify-center">
              <%!-- Animated Blobs --%>
              <div class="absolute top-0 left-0 w-full h-full overflow-hidden pointer-events-none opacity-40">
                <div class="absolute -top-20 -left-20 w-96 h-96 bg-coral rounded-full mix-blend-multiply filter blur-3xl animate-blob"></div>
                <div class="absolute -bottom-20 -right-20 w-96 h-96 bg-orange rounded-full mix-blend-multiply filter blur-3xl animate-blob animation-delay-2000"></div>
                <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-pink rounded-full mix-blend-multiply filter blur-3xl animate-blob animation-delay-4000"></div>
              </div>

              <div class="relative z-10 text-center space-y-8 max-w-4xl">
                <h1 class="text-6xl sm:text-7xl lg:text-8xl font-display text-gray-900 leading-[0.9] tracking-tight">
                  recipes that <br/> aren't <span class="text-coral italic">annoying</span> to use.
                </h1>
                <p class="text-xl text-gray-600 max-w-xl mx-auto">
                  The fastest and easiest way to browse, cook, and share your most cherished flavors—all in one place.
                </p>
                
                <div class="max-w-xl mx-auto pt-4">
                  <.form for={%{}} phx-submit="search" class="relative group">
                    <input
                      type="text"
                      name="query"
                      placeholder="Search for a recipe..."
                      class="w-full h-16 pl-6 pr-32 rounded-full border border-parchment bg-white font-body text-lg shadow-xl shadow-gray-200/50 focus:outline-none focus:border-coral transition-colors"
                    />
                    <button class="absolute right-2 top-2 bottom-2 px-6 bg-gray-900 text-white font-bold rounded-full hover:bg-coral transition-all active:scale-95">
                      Search
                    </button>
                  </.form>
                </div>
              </div>
            </div>
          </div>
        </section>

        <%!-- Categories Section (Cream Background) --%>
        <section class="bg-cream py-24 px-4">
          <div class="max-w-7xl mx-auto space-y-12">
            <div class="flex flex-col md:flex-row md:items-end justify-between gap-6">
              <div class="space-y-4">
                <h2 class="text-xs font-bold text-gray-400 uppercase tracking-widest">Discover</h2>
                <h3 class="text-5xl font-display text-gray-900">Explore by category</h3>
              </div>
              <div class="flex gap-3 overflow-x-auto no-scrollbar pb-2">
                <%= for tag <- @tags do %>
                  <.link
                    patch={~p"/recipes?tag=#{tag}"}
                    class="flex-none px-8 py-4 bg-white border border-parchment rounded-full font-body font-bold text-gray-700 hover:scale-105 hover:border-coral transition-all shadow-sm active:scale-95"
                  >
                    {tag}
                  </.link>
                <% end %>
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
              <%= for {recipe, index} <- Enum.with_index(Enum.take(@recipes, 3)) do %>
                <% 
                  colors = ["bg-pink", "bg-orange", "bg-blue", "bg-coral", "bg-red"]
                  color = Enum.at(colors, rem(index, length(colors)))
                %>
                <.recipe_card recipe={recipe} accent_color={color} />
              <% end %>
            </div>
          </div>
        </section>

        <%!-- Spotlight Section (White Background) --%>
        <section class="bg-white py-24 px-4">
          <div class="max-w-7xl mx-auto">
            <.link navigate={~p"/recipes/#{@featured.slug}"} class="group block relative overflow-hidden rounded-[48px] border border-parchment bg-white shadow-2xl hover:shadow-coral/10 transition-all duration-500">
              <div class="grid grid-cols-1 lg:grid-cols-2 min-h-[500px]">
                <div class="p-8 sm:p-16 space-y-8 flex flex-col justify-center">
                  <div class="space-y-4">
                    <span class="px-4 py-1 bg-coral text-white text-[10px] font-bold uppercase tracking-widest rounded-full">
                      Baker's Spotlight
                    </span>
                    <h3 class="text-6xl sm:text-7xl font-display text-gray-900 leading-tight group-hover:text-coral transition-colors">
                      {@featured.title}
                    </h3>
                    <p class="text-xl text-gray-600 max-w-md leading-relaxed">
                      {@featured.summary}
                    </p>
                  </div>
                  
                  <div class="flex gap-8 border-t border-parchment pt-8">
                    <div>
                      <span class="block text-[10px] font-bold text-gray-400 uppercase tracking-widest mb-1">Time</span>
                      <span class="text-2xl font-display text-gray-900">{@featured.time.total_minutes}m</span>
                    </div>
                    <div>
                      <span class="block text-[10px] font-bold text-gray-400 uppercase tracking-widest mb-1">Ingredients</span>
                      <span class="text-2xl font-display text-gray-900">{length(@featured.ingredients)}</span>
                    </div>
                  </div>
                </div>
                <div class="bg-coral h-full min-h-[300px] relative overflow-hidden flex items-center justify-center p-12">
                  <%!-- Abstract Visual --%>
                  <div class="size-64 rounded-[64px] bg-white/20 rotate-12 group-hover:rotate-45 transition-transform duration-1000 scale-150"></div>
                  <div class="absolute inset-0 bg-gradient-to-br from-transparent to-black/10"></div>
                  <div class="relative z-10 text-white font-display text-9xl opacity-20 pointer-events-none">
                    {String.at(@featured.title, 0)}
                  </div>
                </div>
              </div>
            </.link>
          </div>
        </section>
      </div>
    </RouxLiveWeb.Layouts.app>
    """
  end

  attr :recipe, :map, required: true
  attr :accent_color, :string, default: "bg-coral"

  def recipe_card(assigns) do
    ~H"""
    <.link navigate={~p"/recipes/#{@recipe.slug}"} class="group block h-full">
      <div class="h-full rounded-recipe border border-parchment bg-white overflow-hidden shadow-sm hover:shadow-xl hover:scale-[1.02] transition-all duration-300 flex flex-col">
        <div class={["h-48 relative overflow-hidden", @accent_color]}>
          <%!-- Card Header / Visual --%>
          <div class="absolute top-4 left-4 flex gap-2">
            <%= for tag <- Enum.take(@recipe.tags, 2) do %>
              <span class="px-3 py-1 bg-white/20 backdrop-blur-md text-white text-[10px] font-bold uppercase tracking-widest rounded-full">
                {tag}
              </span>
            <% end %>
          </div>
          <div class="absolute bottom-4 right-4 text-white text-xs font-bold bg-black/10 backdrop-blur-md px-3 py-1 rounded-full">
            {@recipe.time.total_minutes}m
          </div>
          <%!-- Decorative Initial --%>
          <div class="absolute inset-0 flex items-center justify-center text-white/10 text-9xl font-display pointer-events-none group-hover:scale-110 transition-transform duration-700">
            {String.at(@recipe.title, 0)}
          </div>
        </div>
        <div class="p-8 space-y-4 flex-1">
          <h4 class="text-2xl font-display text-gray-900 group-hover:text-coral transition-colors leading-tight">
            {@recipe.title}
          </h4>
          <p class="text-gray-500 line-clamp-2 leading-relaxed text-sm">
            {@recipe.summary}
          </p>
        </div>
      </div>
    </.link>
    """
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/recipes?search=#{query}")}
  end
end
