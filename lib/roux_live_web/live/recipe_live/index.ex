defmodule RouxLiveWeb.RecipeLive.Index do
  use RouxLiveWeb, :live_view
  alias RouxLive.Content.RecipeLoader

  def mount(params, _session, socket) do
    recipes = RecipeLoader.list_all()
    
    tags = 
      recipes 
      |> Enum.flat_map(& &1.tags) 
      |> Enum.uniq() 
      |> Enum.sort()

    {:ok, 
     socket 
     |> assign(:all_recipes, recipes)
     |> assign(:tags, tags)
     |> apply_filters(params)}
  end

  def handle_params(params, _url, socket) do
    {:noreply, apply_filters(socket, params)}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, push_patch(socket, to: ~p"/recipes?search=#{query}&tag=#{socket.assigns.selected_tag}")}
  end

  defp apply_filters(socket, params) do
    search = params["search"] || ""
    tag = params["tag"] || ""
    
    filtered_recipes = 
      socket.assigns.all_recipes
      |> Enum.filter(fn r ->
        matches_search = 
          search == "" || 
          String.contains?(String.downcase(r.title), String.downcase(search)) ||
          String.contains?(String.downcase(r.summary || ""), String.downcase(search))
          
        matches_tag = tag == "" || tag in r.tags
        
        matches_search && matches_tag
      end)
      |> Enum.sort_by(& &1.title)

    grouped_recipes = 
      filtered_recipes
      |> Enum.group_by(fn r -> String.upcase(String.at(r.title, 0)) end)
      |> Enum.sort_by(fn {letter, _} -> letter end)

    socket
    |> assign(:search_query, search)
    |> assign(:selected_tag, tag)
    |> assign(:grouped_recipes, grouped_recipes)
    |> assign(:results_count, length(filtered_recipes))
  end

  def render(assigns) do
    ~H"""
    <RouxLiveWeb.Layouts.app flash={@flash}>
      <div class="font-body pt-32 pb-20">
        <header class="max-w-7xl mx-auto px-4 space-y-12">
          <div class="space-y-4">
            <h1 class="text-7xl sm:text-8xl font-display text-gray-900 leading-[0.9] tracking-tight">
              Recipe <span class="text-coral italic underline decoration-parchment underline-offset-8">Index</span>
            </h1>
            <p class="text-xl text-gray-600 max-w-xl">
              Browse our collection of family favorites, from breakfast staples to decadent desserts.
            </p>
          </div>

          <div class="flex flex-col lg:flex-row gap-6 items-center w-full">
            <div class="relative flex-[2] w-full group min-w-0">
              <form phx-change="search" phx-submit="search" class="relative w-full">
                <input
                  type="text"
                  name="query"
                  value={@search_query}
                  placeholder="Search recipes..."
                  class="w-full h-16 pl-14 pr-4 rounded-3xl border border-parchment bg-white shadow-sm group-focus-within:shadow-xl group-focus-within:border-coral transition-all outline-none text-lg text-gray-900"
                  phx-debounce="300"
                />
                <div class="absolute left-5 top-1/2 -translate-y-1/2 text-gray-400 group-focus-within:text-coral transition-colors">
                  <.icon name="hero-magnifying-glass" class="size-6" />
                </div>
              </form>
            </div>
            
            <div class="flex-1 flex gap-2 overflow-x-auto no-scrollbar w-full lg:w-auto pb-2 min-w-0">
              <.link
                patch={~p"/recipes?search=#{@search_query}"}
                class={[
                  "px-8 py-4 rounded-2xl font-bold transition-all whitespace-nowrap shadow-sm active:scale-95",
                  if(@selected_tag == "", do: "bg-gray-900 text-white shadow-xl", else: "bg-white text-gray-600 border border-parchment hover:border-coral")
                ]}
              >
                All
              </.link>
              <%= for tag <- @tags do %>
                <.link
                  patch={~p"/recipes?search=#{@search_query}&tag=#{tag}"}
                  class={[
                    "px-8 py-4 rounded-2xl font-bold transition-all whitespace-nowrap shadow-sm active:scale-95",
                    if(@selected_tag == tag, do: "bg-gray-900 text-white shadow-xl", else: "bg-white text-gray-600 border border-parchment hover:border-coral")
                  ]}
                >
                  {tag}
                </.link>
              <% end %>
            </div>
          </div>
        </header>

        <div class="max-w-7xl mx-auto px-4 mt-20 space-y-24">
          <%= if @results_count == 0 do %>
            <div class="text-center py-32 bg-linen rounded-[48px] border-2 border-dashed border-parchment">
              <div class="text-6xl mb-6">🍳</div>
              <h3 class="text-3xl font-display text-gray-900">No recipes found</h3>
              <p class="text-gray-500 text-lg">Try adjusting your search or filters.</p>
              <.link patch={~p"/recipes"} class="inline-block mt-8 px-8 py-4 bg-coral text-white font-bold rounded-full hover:scale-105 transition-transform active:scale-95">
                Clear all filters
              </.link>
            </div>
          <% else %>
            <%= for {letter, recipes} <- @grouped_recipes do %>
              <section class="space-y-10">
                <div class="sticky top-24 z-10 bg-canvas/80 backdrop-blur-md py-4 border-b border-parchment flex items-baseline gap-6">
                  <h2 class="text-6xl font-display text-gray-900 leading-none">{letter}</h2>
                  <span class="text-sm font-bold text-gray-400 uppercase tracking-widest">{length(recipes)} recipes</span>
                </div>
                
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-10">
                  <%= for {recipe, index} <- Enum.with_index(recipes) do %>
                    <% 
                      colors = ["bg-pink", "bg-orange", "bg-blue", "bg-coral", "bg-red"]
                      color = Enum.at(colors, rem(index, length(colors)))
                    %>
                    <.recipe_card recipe={recipe} accent_color={color} plan={@plan} />
                  <% end %>
                </div>
              </section>
            <% end %>
          <% end %>
        </div>
      </div>
    </RouxLiveWeb.Layouts.app>
    """
  end

  attr :recipe, :map, required: true
  attr :accent_color, :string, default: "bg-coral"
  attr :plan, :list, required: true

  def recipe_card(assigns) do
    ~H"""
    <div class="group relative h-full">
      <button 
        phx-click="toggle_plan" 
        phx-value-slug={@recipe.slug}
        class={[
          "absolute top-6 right-6 z-20 size-12 rounded-full border flex items-center justify-center transition-all duration-300",
          if(@recipe.slug in @plan, 
            do: "bg-coral border-coral text-white shadow-lg", 
            else: "bg-white/20 backdrop-blur-md border-white/30 text-gray-900 hover:bg-white/40")
        ]}
      >
        <.icon name={if @recipe.slug in @plan, do: "hero-check", else: "hero-plus"} class="size-6" />
      </button>

      <.link navigate={~p"/recipes/#{@recipe.slug}"} class="block h-full">
        <div class="h-full rounded-recipe border border-parchment bg-white overflow-hidden shadow-sm hover:shadow-2xl hover:shadow-gray-200/50 transition-all duration-500 flex flex-col group-hover:-translate-y-2">
        <div class={["h-56 relative overflow-hidden", @accent_color]}>
          <div class="absolute top-6 left-6 flex gap-2">
            <%= for tag <- Enum.take(@recipe.tags, 2) do %>
              <span class="px-3 py-1 bg-white text-[10px] font-bold text-gray-900 uppercase tracking-widest rounded-full shadow-sm">
                {tag}
              </span>
            <% end %>
          </div>
          <div class="absolute bottom-6 right-6 text-white text-[10px] font-bold bg-black/20 backdrop-blur-md px-4 py-1.5 rounded-full uppercase tracking-widest">
            {@recipe.time.total_minutes} min
          </div>
          <div class="absolute inset-0 flex items-center justify-center text-white/10 text-[12rem] font-display pointer-events-none group-hover:scale-125 group-hover:rotate-6 transition-transform duration-1000">
            {String.at(@recipe.title, 0)}
          </div>
        </div>
        <div class="p-10 space-y-4 flex-1 flex flex-col justify-between">
          <div class="space-y-4">
            <h4 class="text-3xl font-display text-gray-900 group-hover:text-coral transition-colors leading-tight">
              {@recipe.title}
            </h4>
            <p class="text-gray-500 line-clamp-3 leading-relaxed">
              {@recipe.summary}
            </p>
          </div>
          <div class="pt-6 border-t border-linen flex items-center text-xs font-bold text-gray-400 uppercase tracking-widest group-hover:text-coral transition-colors">
            View Recipe <span class="ml-2 group-hover:translate-x-2 transition-transform">&rarr;</span>
          </div>
        </div>
      </div>
    </.link>
  </div>
  """
end
end
