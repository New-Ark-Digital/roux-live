defmodule RouxLiveWeb.RecipeLive.Show do
  use RouxLiveWeb, :live_view
  alias RouxLive.Content.RecipeLoader

  def mount(%{"slug" => slug}, _session, socket) do
    recipe = RecipeLoader.load!(slug)

    {:ok,
     socket
     |> assign(:recipe, recipe)
     |> assign(:active_step_id, List.first(recipe.steps).id)
     |> assign(:show_mobile_ingredients, false)
     |> assign(:page_title, recipe.title)}
  end

  def handle_event("select_step", %{"id" => id}, socket) do
    {:noreply, assign(socket, :active_step_id, id)}
  end

  def handle_event("toggle_mobile_ingredients", _params, socket) do
    {:noreply, update(socket, :show_mobile_ingredients, &(!&1))}
  end

  def render(assigns) do
    active_step = Enum.find(assigns.recipe.steps, &(&1.id == assigns.active_step_id))
    active_step_index = Enum.find_index(assigns.recipe.steps, &(&1.id == assigns.active_step_id))
    highlighted_ids = (active_step && active_step.uses) || []

    active_ingredients = Enum.filter(assigns.recipe.ingredients, &(&1.id in highlighted_ids))

    assigns =
      assign(assigns,
        active_step: active_step,
        active_step_index: active_step_index,
        highlighted_ids: highlighted_ids,
        active_ingredients: active_ingredients
      )

    ~H"""
    <RouxLiveWeb.Layouts.app
      flash={@flash}
      active_ingredients={@active_ingredients}
      active_step_index={@active_step_index}
    >
      <div class="font-body pt-24 lg:pt-28">
        <%!-- Content Section (White Background) --%>
        <section class="bg-white px-4">
          <div class="max-w-7xl mx-auto grid grid-cols-1 lg:grid-cols-12 gap-12 lg:h-[calc(100vh-140px)] lg:min-h-[600px] items-stretch">
            <%!-- Mobile Ingredients Toggle (Visible on Mobile Only) --%>
            <div class="lg:hidden w-full space-y-4">
              <button
                phx-click="toggle_mobile_ingredients"
                class="w-full flex items-center justify-between p-6 bg-cream border border-parchment rounded-[32px] font-display text-2xl text-gray-900"
              >
                <span>Ingredients</span>
                <span class={[
                  "transition-transform duration-300",
                  @show_mobile_ingredients && "rotate-180"
                ]}>
                  <.icon name="hero-chevron-down" class="size-6" />
                </span>
              </button>

              <div class={[
                "overflow-hidden transition-all duration-500",
                if(@show_mobile_ingredients,
                  do: "max-h-[2000px] opacity-100 mb-8",
                  else: "max-h-0 opacity-0"
                )
              ]}>
                <div class="bg-cream p-8 px-10 rounded-[32px] border border-parchment space-y-8">
                  <.render_ingredients recipe={@recipe} highlighted_ids={@highlighted_ids} />
                </div>
              </div>
            </div>

            <%!-- Sidebar Column (Left on Desktop: Title, Stats, Ingredients, Notes) --%>
            <div class="hidden lg:flex lg:col-span-5 flex-col gap-6 overflow-hidden h-full">
              <div class="bg-cream p-10 px-2 rounded-[48px] border border-parchment flex flex-col min-h-0 flex-1 shadow-sm">
                <%!-- Recipe Header inside Sidebar --%>
                <div class="px-8 pb-6 border-b border-parchment/20 space-y-4 shrink-0">
                  <div class="flex flex-wrap gap-2">
                    <%= for tag <- @recipe.tags do %>
                      <span class="px-2 py-0.5 bg-white/50 text-gray-500 text-[8px] font-bold uppercase tracking-widest rounded-full border border-parchment/30">
                        {tag}
                      </span>
                    <% end %>
                  </div>
                  <h1 class="text-4xl font-display text-gray-900 leading-tight">
                    {@recipe.title}
                  </h1>
                  <div class="flex flex-wrap gap-x-4 gap-y-2 text-[9px] font-bold text-gray-400 uppercase tracking-widest">
                    <span>P: {@recipe.time.prep_minutes}m</span>
                    <span>C: {@recipe.time.cook_minutes}m</span>
                    <span>T: {@recipe.time.total_minutes}m</span>
                    <span>Y: {@recipe.yield.quantity} {@recipe.yield.unit}</span>
                  </div>
                </div>

                <%!-- Context Summary Header --%>
                <div
                  :if={@active_ingredients != []}
                  class="px-8 py-4 bg-linen/50 border-b border-parchment/20"
                >
                  <div class="flex items-center gap-2 mb-2">
                    <span class="size-1.5 rounded-full bg-coral animate-pulse"></span>
                    <span class="text-[10px] font-bold text-gray-400 uppercase tracking-widest">
                      Active Ingredients
                    </span>
                  </div>
                  <div class="flex flex-wrap gap-2">
                    <%= for ingredient <- @active_ingredients do %>
                      <span class="text-[10px] font-bold text-coral bg-white border border-coral/20 px-2 py-0.5 rounded-full">
                        {ingredient.name}
                      </span>
                    <% end %>
                  </div>
                </div>

                <%!-- Scrollable Ingredients --%>
                <div class="relative flex-1 min-h-0 flex overflow-hidden">
                  <%!-- Indicator Strip (Pips) --%>
                  <div id="ingredient-pips" class="w-1.5 h-full relative pointer-events-none ml-4">
                    <%!-- JS Hook will inject pips here --%>
                  </div>

                  <div
                    id="ingredients-list-container"
                    phx-hook="IngredientAutoScroll"
                    class="overflow-y-auto custom-scrollbar space-y-10 flex-1 px-8 py-8 relative"
                  >
                    <.render_ingredients recipe={@recipe} highlighted_ids={@highlighted_ids} />
                  </div>
                </div>
              </div>

              <%!-- Pinned Notes --%>
              <%= if @recipe.notes != [] do %>
                <div class="bg-gray-900 p-8 rounded-[40px] text-white space-y-4 shadow-2xl shrink-0">
                  <h3 class="text-xl font-display text-coral italic">Baker's Notes</h3>
                  <ul class="space-y-3">
                    <%= for note <- @recipe.notes do %>
                      <li class="text-sm text-gray-300 leading-relaxed flex gap-4">
                        <span class="text-coral flex-none pt-1.5">•</span> {note}
                      </li>
                    <% end %>
                  </ul>
                </div>
              <% end %>
            </div>

            <%!-- Main Column (Right on Desktop: Instructions) --%>
            <div class="lg:col-span-7 flex flex-col h-full overflow-hidden">
              <div class="lg:hidden space-y-4 mb-8">
                <h1 class="text-5xl font-display text-gray-900 leading-tight">{@recipe.title}</h1>
                <div class="flex flex-wrap gap-4 text-[10px] font-bold text-gray-400 uppercase tracking-widest">
                  <span>Total: {@recipe.time.total_minutes}m</span>
                  <span>Yield: {@recipe.yield.quantity} {@recipe.yield.unit}</span>
                </div>
              </div>

              <div class="flex-1 overflow-y-auto custom-scrollbar lg:pr-4 min-h-0">
                <h2 class="hidden lg:block text-xs font-bold text-gray-400 uppercase tracking-[0.3em] mb-8">
                  Instructions
                </h2>
                <div class="space-y-16 pb-12">
                  <%= if @recipe.step_groups != [] do %>
                    <%= for group <- @recipe.step_groups do %>
                      <div class="space-y-8">
                        <h3 class="text-xs font-bold text-gray-400 uppercase tracking-widest border-b border-linen pb-4 flex items-center">
                          <span class="bg-coral size-2 rounded-full mr-3"></span>
                          {group.title}
                        </h3>
                        <div class="space-y-6">
                          <%= for step_id <- group.step_ids do %>
                            <% step = Enum.find(@recipe.steps, &(&1.id == step_id))
                            index = Enum.find_index(@recipe.steps, &(&1.id == step_id)) %>
                            <.step_item step={step} index={index} active_step_id={@active_step_id} />
                          <% end %>
                        </div>
                      </div>
                    <% end %>
                  <% else %>
                    <div class="space-y-6">
                      <%= for {step, index} <- Enum.with_index(@recipe.steps) do %>
                        <.step_item step={step} index={index} active_step_id={@active_step_id} />
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </section>

        <%!-- Mobile Notes (Visible on Mobile Only) --%>
        <section :if={@recipe.notes != []} class="lg:hidden bg-white pb-20 px-4">
          <div class="max-w-7xl mx-auto">
            <div class="bg-gray-900 p-8 rounded-[40px] text-white space-y-4 shadow-2xl">
              <h3 class="text-xl font-display text-coral italic">Baker's Notes</h3>
              <ul class="space-y-3">
                <%= for note <- @recipe.notes do %>
                  <li class="text-sm text-gray-300 leading-relaxed flex gap-4">
                    <span class="text-coral flex-none pt-1.5">•</span> {note}
                  </li>
                <% end %>
              </ul>
            </div>
          </div>
        </section>
      </div>
    </RouxLiveWeb.Layouts.app>
    """
  end

  defp render_ingredients(assigns) do
    ~H"""
    <%= if @recipe.ingredient_groups != [] do %>
      <%= for group <- @recipe.ingredient_groups do %>
        <div class="space-y-6">
          <h3 class="text-[10px] font-bold text-gray-400 uppercase tracking-[0.2em]">
            {group.title}
          </h3>
          <ul class="space-y-4">
            <%= for ingredient_id <- group.ingredient_ids do %>
              <% ingredient = Enum.find(@recipe.ingredients, &(&1.id == ingredient_id)) %>
              <.ingredient_item
                ingredient={ingredient}
                highlighted={ingredient.id in @highlighted_ids}
              />
            <% end %>
          </ul>
        </div>
      <% end %>
    <% else %>
      <ul class="space-y-4">
        <%= for ingredient <- @recipe.ingredients do %>
          <.ingredient_item ingredient={ingredient} highlighted={ingredient.id in @highlighted_ids} />
        <% end %>
      </ul>
    <% end %>
    """
  end

  attr :step, :map, required: true
  attr :index, :integer, required: true
  attr :active_step_id, :string, required: true

  def step_item(assigns) do
    ~H"""
    <div
      phx-click="select_step"
      phx-value-id={@step.id}
      class={[
        "p-8 rounded-[32px] border transition-all cursor-pointer group flex flex-col gap-4",
        if(@active_step_id == @step.id,
          do: "bg-white border-coral shadow-2xl shadow-coral/5 -translate-y-1",
          else: "bg-white border-parchment hover:border-coral/30"
        )
      ]}
    >
      <div class="flex gap-6">
        <span class={[
          "flex-none flex items-center justify-center size-10 rounded-2xl text-base font-bold transition-all",
          if(@active_step_id == @step.id,
            do: "bg-coral text-white rotate-6",
            else: "bg-linen text-gray-400 group-hover:bg-coral/10 group-hover:text-coral"
          )
        ]}>
          {@index + 1}
        </span>
        <p class={[
          "text-xl leading-relaxed transition-colors",
          if(@active_step_id == @step.id, do: "text-gray-900 font-medium", else: "text-gray-500")
        ]}>
          {@step.text}
        </p>
      </div>
    </div>
    """
  end

  attr :ingredient, :map, required: true
  attr :highlighted, :boolean, default: false

  def ingredient_item(assigns) do
    ~H"""
    <li
      data-highlighted={to_string(@highlighted)}
      class={[
        "flex justify-between items-baseline gap-4 p-4 rounded-2xl transition-all border border-transparent",
        if(@highlighted,
          do: "bg-white border-parchment shadow-lg scale-105",
          else: "opacity-60 grayscale-[0.5]"
        )
      ]}
    >
      <span class={[
        "text-lg transition-colors",
        if(@highlighted, do: "text-gray-900 font-bold", else: "text-gray-700")
      ]}>
        {@ingredient.name}
        <%= if @ingredient.note do %>
          <span class="text-xs font-normal opacity-60">({@ingredient.note})</span>
        <% end %>
      </span>
      <span class="text-sm font-bold text-gray-400 whitespace-nowrap bg-linen px-3 py-1 rounded-full uppercase tracking-tighter">
        {@ingredient.amount} {@ingredient.unit}
      </span>
    </li>
    """
  end
end
