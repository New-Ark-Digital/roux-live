defmodule RouxLiveWeb.RecipeLive.Show do
  use RouxLiveWeb, :live_view
  alias RouxLive.Content.RecipeLoader

  def mount(%{"slug" => slug}, _session, socket) do
    recipe = RecipeLoader.load!(slug)
    {:ok,
     socket
     |> assign(:recipe, recipe)
     |> assign(:active_step_id, List.first(recipe.steps).id)
     |> assign(:page_title, recipe.title)}
  end

  def handle_event("select_step", %{"id" => id}, socket) do
    {:noreply, assign(socket, :active_step_id, id)}
  end

  def render(assigns) do
    active_step = Enum.find(assigns.recipe.steps, &(&1.id == assigns.active_step_id))
    active_step_index = Enum.find_index(assigns.recipe.steps, &(&1.id == assigns.active_step_id))
    highlighted_ids = (active_step && active_step.uses) || []
    active_ingredients = Enum.filter(assigns.recipe.ingredients, &(&1.id in highlighted_ids))
    assigns = assign(assigns, 
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
      <div class="space-y-0 font-body">
        <%!-- Header Section (Cream Background) --%>
        <section class="bg-cream pt-32 pb-20 px-4">
          <div class="max-w-7xl mx-auto">
            <div class="bg-white p-8 sm:p-16 rounded-[48px] border border-parchment shadow-xl space-y-10 relative overflow-hidden">
              <%!-- Decorative Background --%>
              <div class="absolute -right-20 -top-20 size-96 bg-coral/5 rounded-full blur-3xl"></div>
              
              <div class="relative z-10 space-y-6">
                <div class="flex flex-wrap gap-2">
                  <%= for tag <- @recipe.tags do %>
                    <span class="px-4 py-1.5 bg-linen text-gray-600 text-[10px] font-bold uppercase tracking-widest rounded-full border border-parchment">
                      {tag}
                    </span>
                  <% end %>
                </div>
                <h1 class="text-6xl sm:text-7xl lg:text-8xl font-display text-gray-900 leading-[0.9] tracking-tight">
                  {@recipe.title}
                </h1>
                <p class="text-xl text-gray-600 max-w-3xl leading-relaxed">
                  {@recipe.summary}
                </p>
              </div>

              <div class="relative z-10 grid grid-cols-2 md:grid-cols-4 gap-6 pt-10 border-t border-linen">
                <div class="space-y-1">
                  <span class="block text-[10px] font-bold text-gray-400 uppercase tracking-widest">Prep Time</span>
                  <span class="text-2xl font-display text-gray-900">{@recipe.time.prep_minutes}m</span>
                </div>
                <div class="space-y-1 border-l border-linen pl-6">
                  <span class="block text-[10px] font-bold text-gray-400 uppercase tracking-widest">Cook Time</span>
                  <span class="text-2xl font-display text-gray-900">{@recipe.time.cook_minutes}m</span>
                </div>
                <div class="space-y-1 border-l border-linen pl-6">
                  <span class="block text-[10px] font-bold text-gray-400 uppercase tracking-widest">Total Time</span>
                  <span class="text-2xl font-display text-gray-900">{@recipe.time.total_minutes}m</span>
                </div>
                <div class="space-y-1 border-l border-linen pl-6">
                  <span class="block text-[10px] font-bold text-gray-400 uppercase tracking-widest">Yield</span>
                  <span class="text-2xl font-display text-gray-900">{@recipe.yield.quantity} {@recipe.yield.unit}</span>
                </div>
              </div>
            </div>
          </div>
        </section>

        <%!-- Content Section (White Background) --%>
        <section class="bg-white py-24 px-4">
          <div class="max-w-7xl mx-auto grid grid-cols-1 lg:grid-cols-12 gap-16 items-start">
            <%!-- Steps Section (Left) --%>
            <div class="lg:col-span-7 space-y-12">
              <h2 class="text-5xl font-display text-gray-900">Instructions</h2>
              <div class="space-y-16">
                <%= if @recipe.step_groups != [] do %>
                  <%= for group <- @recipe.step_groups do %>
                    <div class="space-y-8">
                      <h3 class="text-xs font-bold text-gray-400 uppercase tracking-widest border-b border-linen pb-4 flex items-center">
                        <span class="bg-coral size-2 rounded-full mr-3"></span>
                        {group.title}
                      </h3>
                      <div class="space-y-6">
                        <%= for step_id <- group.step_ids do %>
                          <% 
                            step = Enum.find(@recipe.steps, &(&1.id == step_id))
                            index = Enum.find_index(@recipe.steps, &(&1.id == step_id))
                          %>
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

            <%!-- Ingredients Section (Right) --%>
            <div class="lg:col-span-5 space-y-10 sticky top-32">
              <div class="bg-cream p-10 rounded-[48px] border border-parchment space-y-10">
                <h2 class="text-4xl font-display text-gray-900">Ingredients</h2>
                
                <div class="space-y-10">
                  <%= if @recipe.ingredient_groups != [] do %>
                    <%= for group <- @recipe.ingredient_groups do %>
                      <div class="space-y-6">
                        <h3 class="text-[10px] font-bold text-gray-400 uppercase tracking-[0.2em]">{group.title}</h3>
                        <ul class="space-y-4">
                          <%= for ingredient_id <- group.ingredient_ids do %>
                            <% ingredient = Enum.find(@recipe.ingredients, &(&1.id == ingredient_id)) %>
                            <.ingredient_item ingredient={ingredient} highlighted={ingredient.id in @highlighted_ids} />
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
                </div>
              </div>

              <%= if @recipe.notes != [] do %>
                <div class="bg-gray-900 p-10 rounded-[40px] text-white space-y-6 shadow-2xl">
                  <h3 class="text-2xl font-display text-coral italic">Baker's Notes</h3>
                  <ul class="space-y-4">
                    <%= for note <- @recipe.notes do %>
                      <li class="text-sm text-gray-300 leading-relaxed flex gap-4">
                        <span class="text-coral flex-none pt-1.5">•</span> {note}
                      </li>
                    <% end %>
                  </ul>
                </div>
              <% end %>
            </div>
          </div>
        </section>
      </div>
    </RouxLiveWeb.Layouts.app>
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
          if(@active_step_id == @step.id, do: "bg-coral text-white rotate-6", else: "bg-linen text-gray-400 group-hover:bg-coral/10 group-hover:text-coral")
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
    <li class={[
      "flex justify-between items-baseline gap-4 p-4 rounded-2xl transition-all border border-transparent",
      if(@highlighted, do: "bg-white border-parchment shadow-lg scale-105", else: "opacity-60 grayscale-[0.5]")
    ]}>
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
