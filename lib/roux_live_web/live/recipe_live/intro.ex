defmodule RouxLiveWeb.RecipeLive.Intro do
  use RouxLiveWeb, :live_view
  alias RouxLive.Content.RecipeLoader

  def mount(%{"slug" => slug}, _session, socket) do
    recipe = RecipeLoader.load!(slug)

    {:ok,
     socket
     |> assign(:recipe, recipe)
     |> assign(:page_title, recipe.title)}
  end

  def render(assigns) do
    ~H"""
    <RouxLiveWeb.Layouts.app flash={@flash} plan_count={@plan_count}>
      <div class="font-body pt-32 pb-24">
        <div class="max-w-7xl mx-auto px-4 space-y-16">
          <%!-- Editorial Hero --%>
          <header class="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
            <div class="space-y-8">
              <div class="flex flex-wrap gap-2">
                <%= for tag <- @recipe.tags do %>
                  <span class="px-4 py-1.5 bg-linen text-gray-600 text-[10px] font-bold uppercase tracking-widest rounded-full border border-parchment">
                    {tag}
                  </span>
                <% end %>
              </div>
              <h1 class="text-7xl sm:text-8xl font-display text-gray-900 leading-[0.9] tracking-tight">
                {@recipe.title}
              </h1>
              <p class="text-xl text-gray-600 leading-relaxed max-w-xl">
                {@recipe.summary}
              </p>

              <div class="flex items-center pt-4">
                <div class="inline-flex items-center p-1 rounded-full bg-linen/50 border border-parchment shadow-sm leading-none">
                  <%!-- 1. Plan Toggle --%>
                  <button
                    phx-click="toggle_plan"
                    phx-value-slug={@recipe.slug}
                    class={[
                      "px-5 py-2 rounded-full flex items-center gap-2 transition-all active:scale-95",
                      if(@recipe.slug in @plan,
                        do: "bg-coral text-white shadow-md",
                        else: "text-gray-500 hover:bg-white hover:text-gray-700"
                      )
                    ]}
                  >
                    <.icon
                      name={if @recipe.slug in @plan, do: "hero-check", else: "hero-plus"}
                      class="size-3.5"
                    />
                    <span class="text-[10px] font-bold uppercase tracking-wider">
                      {if @recipe.slug in @plan, do: "Added", else: "Plan"}
                    </span>
                  </button>

                  <div class="w-px h-4 bg-parchment mx-1"></div>

                  <%!-- 2. Start Standard --%>
                  <.link
                    navigate={~p"/cook/#{@recipe.slug}"}
                    phx-click={JS.push("change_preferred_mode", value: %{mode: "standard"})}
                    class={[
                      "px-5 py-2 rounded-full flex flex-col items-start justify-center gap-0.5 transition-all active:scale-95",
                      if(@preferred_mode == "standard",
                        do: "bg-white text-gray-900 shadow-sm border border-parchment/50",
                        else: "text-gray-400 hover:text-gray-600 hover:bg-white/50"
                      )
                    ]}
                  >
                    <span class="text-[7px] font-bold text-coral uppercase tracking-[0.2em]">
                      Start
                    </span>
                    <span class="text-[10px] font-bold uppercase tracking-tight">Standard</span>
                  </.link>

                  <%!-- 3. Start Focus --%>
                  <.link
                    navigate={~p"/run/#{@recipe.slug}"}
                    phx-click={JS.push("change_preferred_mode", value: %{mode: "focus"})}
                    class={[
                      "px-5 py-2 rounded-full flex flex-col items-start justify-center gap-0.5 transition-all active:scale-95",
                      if(@preferred_mode == "focus",
                        do: "bg-white text-gray-900 shadow-sm border border-parchment/50",
                        else: "text-gray-400 hover:text-gray-600 hover:bg-white/50"
                      )
                    ]}
                  >
                    <span class="text-[7px] font-bold text-coral uppercase tracking-[0.2em]">
                      Start
                    </span>
                    <span class="text-[10px] font-bold uppercase tracking-tight">Focus</span>
                  </.link>
                </div>
              </div>
            </div>

            <div class="relative overflow-hidden rounded-[64px] bg-cream border border-parchment mesh-gradient p-12 aspect-square flex items-center justify-center">
              <div class="absolute inset-0 opacity-40">
                <div class="absolute -top-20 -left-20 w-96 h-96 bg-coral rounded-full blur-3xl animate-blob">
                </div>
                <div class="absolute -bottom-20 -right-20 w-96 h-96 bg-orange rounded-full blur-3xl animate-blob animation-delay-2000">
                </div>
              </div>
              <div class="relative z-10 text-white font-display text-[15rem] opacity-20 select-none">
                {String.at(@recipe.title, 0)}
              </div>
            </div>
          </header>

          <%!-- Checklist Bento --%>
          <section class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            <%!-- Stats & Equipment --%>
            <div class="space-y-8">
              <div class="bg-linen p-8 rounded-[40px] border border-parchment space-y-6">
                <h3 class="text-xs font-bold text-gray-400 uppercase tracking-widest">Details</h3>
                <div class="grid grid-cols-2 gap-6">
                  <div>
                    <span class="block text-[10px] font-bold text-gray-400 uppercase mb-1">Time</span>
                    <span class="text-xl font-display text-gray-900">
                      {@recipe.time.total_minutes}m
                    </span>
                  </div>
                  <div>
                    <span class="block text-[10px] font-bold text-gray-400 uppercase mb-1">
                      Yield
                    </span>
                    <span class="text-xl font-display text-gray-900">
                      {@recipe.yield.quantity} {@recipe.yield.unit}
                    </span>
                  </div>
                </div>
              </div>

              <div class="bg-cream p-8 rounded-[40px] border border-parchment space-y-6">
                <div class="flex justify-between items-center">
                  <h3 class="text-xs font-bold text-gray-400 uppercase tracking-widest">Equipment</h3>
                  <.icon name="hero-beaker" class="size-4 text-gray-300" />
                </div>
                <%= if @recipe.equipment != [] do %>
                  <ul class="space-y-3">
                    <%= for item <- @recipe.equipment do %>
                      <li class="flex items-center gap-3 text-gray-700">
                        <span class="size-1.5 rounded-full bg-coral"></span>
                        {item.name}
                      </li>
                    <% end %>
                  </ul>
                <% else %>
                  <p class="text-sm text-gray-400 italic text-center py-4">Standard kitchen tools</p>
                <% end %>
              </div>
            </div>

            <%!-- Ingredients Reference --%>
            <div class="bg-linen p-10 rounded-[48px] border border-parchment space-y-8">
              <div class="flex justify-between items-center">
                <h3 class="text-xs font-bold text-gray-400 uppercase tracking-widest">Ingredients</h3>
                <span class="text-[10px] font-bold text-gray-400 uppercase">
                  {length(@recipe.ingredients)} items
                </span>
              </div>

              <ul class="space-y-4">
                <%= for ingredient <- @recipe.ingredients do %>
                  <li class="flex justify-between items-baseline gap-4 border-b border-parchment/30 pb-2">
                    <span class="text-gray-900 font-medium">{ingredient.name}</span>
                    <span class="text-sm text-gray-400 whitespace-nowrap">
                      {ingredient.amount} {ingredient.unit}
                    </span>
                  </li>
                <% end %>
              </ul>
            </div>

            <%!-- Skills & Notes --%>
            <div class="space-y-8">
              <div class="bg-gray-900 p-8 rounded-[40px] text-white space-y-6 shadow-2xl">
                <h3 class="text-xs font-bold text-gray-500 uppercase tracking-widest">Techniques</h3>
                <%= if @recipe.skills != [] do %>
                  <div class="flex flex-wrap gap-2">
                    <%= for skill <- @recipe.skills do %>
                      <span class="px-3 py-1 bg-white/10 text-coral text-xs font-bold rounded-full border border-white/10">
                        {skill}
                      </span>
                    <% end %>
                  </div>
                <% else %>
                  <p class="text-sm text-gray-500 italic">Common cooking skills</p>
                <% end %>
              </div>

              <div class="bg-basil p-8 rounded-[40px] border border-parchment space-y-4">
                <h3 class="text-xl font-display text-gray-900">Notes</h3>
                <ul class="space-y-3">
                  <%= for note <- @recipe.notes do %>
                    <li class="text-sm text-gray-700 leading-relaxed flex gap-3">
                      <span class="text-coral flex-none">•</span> {note}
                    </li>
                  <% end %>
                </ul>
              </div>
            </div>
          </section>
        </div>
      </div>
    </RouxLiveWeb.Layouts.app>
    """
  end
end
