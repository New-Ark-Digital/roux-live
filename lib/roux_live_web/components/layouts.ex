defmodule RouxLiveWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use RouxLiveWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :active_ingredients, :list, default: [], doc: "list of ingredients for the active step"
  attr :active_step_index, :integer, default: nil, doc: "index of the active step"
  attr :plan_count, :integer, default: 0, doc: "number of recipes in the meal plan"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="fixed top-6 left-0 right-0 z-50 px-4 pointer-events-none">
      <nav 
        id="main-nav"
        phx-hook="MealPlan"
        class={[
        "mx-auto w-[calc(100vw-2rem)] max-w-lg bg-white/80 backdrop-blur-xl border border-parchment shadow-2xl shadow-gray-200/50 flex flex-col items-center pointer-events-auto transition-all duration-500 dynamic-island-bezier overflow-hidden p-2",
        if(@active_ingredients != [], do: "rounded-[32px]", else: "rounded-[100px]")
      ]}>
        <%!-- Top Row (Static) --%>
        <div class="flex items-center justify-between w-full pr-2">
          <div class="flex items-center gap-1">
            <a href="/" class="pl-4 pr-4 py-2 text-2xl font-display font-bold text-gray-900 tracking-tight hover:text-coral transition-colors">
              roux
            </a>
            
            <div class="hidden sm:flex items-center gap-1 border-l border-parchment pl-2">
              <.link navigate={~p"/recipes"} class="px-4 py-2 rounded-full font-body font-bold text-gray-600 hover:bg-linen transition-colors">
                Index
              </.link>
              <.link navigate={~p"/plan"} class="px-4 py-2 rounded-full font-body font-bold text-gray-600 hover:bg-linen transition-colors relative">
                Plan
                <span :if={@plan_count > 0} class="absolute -top-1 -right-1 size-5 bg-coral text-white text-[10px] flex items-center justify-center rounded-full border-2 border-white animate-in zoom-in duration-300">
                  {@plan_count}
                </span>
              </.link>
            </div>
          </div>

          <div class="flex items-center gap-1">
            <button class="px-6 py-2.5 bg-gray-900 text-white font-body font-bold rounded-full hover:bg-coral transition-all active:scale-95 text-sm">
              Favorites
            </button>
          </div>
        </div>

        <%!-- The "Belly" (Dynamic Island Expansion - Mobile Only) --%>
        <div 
          id="island-belly"
          phx-hook="DynamicIsland"
          class={[
            "lg:hidden w-full island-height-transition overflow-hidden px-4",
            if(@active_ingredients != [], do: "opacity-100 pb-4", else: "opacity-0 pb-0")
          ]}
        >
          <div class="pt-4 mt-2 border-t border-linen space-y-3">
            <div class="flex justify-between items-center">
              <h3 :if={is_integer(@active_step_index)} class="text-[10px] font-bold text-coral uppercase tracking-widest transition-all animate-in fade-in delay-300 duration-500 fill-mode-both">
                Step {@active_step_index + 1} Ingredients
              </h3>
            </div>
            <div class="flex flex-wrap gap-2 transition-all duration-500">
              <%= for ingredient <- @active_ingredients do %>
                <div class="bg-gray-900 px-3 py-1.5 rounded-full flex items-center gap-2 animate-in fade-in zoom-in delay-500 duration-500 fill-mode-both">
                  <span class="text-xs font-bold text-white uppercase tracking-tighter">
                    {ingredient.name}
                  </span>
                  <span class="text-[10px] text-gray-400 font-bold border-l border-white/20 pl-2">
                    {ingredient.amount} {ingredient.unit}
                  </span>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </nav>
    </div>

    <main class="min-h-screen bg-canvas">
      {render_slot(@inner_block)}
    </main>

    <footer class="bg-cream border-t border-parchment py-20 px-4">
      <div class="max-w-7xl mx-auto flex flex-col md:flex-row justify-between items-center gap-8">
        <div class="space-y-4 text-center md:text-left">
          <a href="/" class="text-3xl font-display font-bold text-gray-900 tracking-tight">
            roux
          </a>
          <p class="text-gray-500 font-body max-w-xs text-sm leading-relaxed">
            Recipes that aren't annoying to use. Built for the modern chef who values clarity and speed.
          </p>
        </div>
        
        <div class="flex flex-wrap justify-center gap-8 text-sm font-bold font-body text-gray-400 uppercase tracking-widest">
          <.link navigate={~p"/"} class="hover:text-coral transition-colors">Home</.link>
          <.link navigate={~p"/recipes"} class="hover:text-coral transition-colors">Recipes</.link>
          <a href="#" class="hover:text-coral transition-colors">About</a>
          <a href="#" class="hover:text-coral transition-colors">Privacy</a>
        </div>

        <div class="text-gray-400 text-xs font-body">
          &copy; 2026 New Ark Digital, LLC. All rights reserved.
        </div>
      </div>
    </footer>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
