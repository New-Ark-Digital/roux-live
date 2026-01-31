defmodule RouxLiveWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component

  use Phoenix.VerifiedRoutes,
    endpoint: RouxLiveWeb.Endpoint,
    router: RouxLiveWeb.Router,
    statics: RouxLiveWeb.static_paths()

  use Gettext, backend: RouxLiveWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc """
  Renders the Sticky Cooking Hero for Standard and Focus modes.
  """
  attr :title, :string, required: true
  attr :plan_count, :integer, default: 0
  attr :active_ingredients, :list, default: []
  attr :progress, :float, default: 0.0
  attr :remaining_text, :string, default: nil
  attr :mode, :string, values: ["standard", "focus"]
  attr :slug, :string, default: nil
  attr :active_task_id, :string, default: nil

  def cooking_hero(assigns) do
    ~H"""
    <header class="fixed top-0 left-0 right-0 z-[100] bg-cream backdrop-blur-xl border-b border-parchment h-48 flex flex-col overflow-hidden">
      <%!-- Floating Top Nav --%>
      <div class="max-w-7xl mx-auto px-4 w-full mt-4 shrink-0">
        <div class="max-w-xl mx-auto bg-white/40 border border-white/60 rounded-full h-12 flex items-center justify-between px-6 shadow-sm">
          <div class="flex items-center gap-3 overflow-hidden">
            <a
              href="/"
              class="text-xl font-display font-bold text-gray-900 tracking-tight hover:text-coral transition-colors shrink-0"
            >
              roux
            </a>
            <span class="text-gray-300 font-light text-lg shrink-0">/</span>
            <h1 class="font-display text-sm text-gray-500 truncate italic">
              {@title}
            </h1>
          </div>

          <div class="flex items-center gap-2 shrink-0">
            <div class="hidden sm:flex items-center gap-1">
              <.link
                navigate={~p"/recipes"}
                class="px-3 py-1 rounded-full font-body font-bold text-gray-500 hover:text-gray-900 transition-all text-[10px] uppercase tracking-wider"
              >
                Index
              </.link>
              <.link
                navigate={~p"/plan"}
                class="px-3 py-1 rounded-full font-body font-bold text-gray-500 hover:text-gray-900 transition-all text-[10px] uppercase tracking-wider relative"
              >
                Plan {@plan_count > 0 && "(#{@plan_count})"}
              </.link>
            </div>

            <%!-- Settings Dropdown --%>
            <div class="relative">
              <button
                phx-click={
                  JS.toggle(
                    to: "#hero-settings-menu",
                    in:
                      {"transition ease-out duration-200", "opacity-0 scale-95",
                       "opacity-100 scale-100"},
                    out:
                      {"transition ease-in duration-150", "opacity-100 scale-100",
                       "opacity-0 scale-95"}
                  )
                }
                class="size-8 flex items-center justify-center rounded-full text-gray-400 hover:text-gray-900 hover:bg-white/50 transition-all"
              >
                <.icon name="hero-cog-6-tooth" class="size-4" />
              </button>
              <div
                id="hero-settings-menu"
                class="hidden absolute right-0 mt-2 w-48 bg-white border border-parchment rounded-2xl shadow-xl z-[110] p-2"
                phx-click-away={
                  JS.hide(
                    to: "#hero-settings-menu",
                    transition:
                      {"transition ease-in duration-150", "opacity-100 scale-100",
                       "opacity-0 scale-95"}
                  )
                }
              >
                <div class="text-[9px] font-bold text-gray-400 uppercase tracking-[0.2em] px-3 py-2">
                  Mode
                </div>
                <.link
                  patch={
                    if @slug,
                      do: ~p"/cook/#{@slug}/task/#{@active_task_id}",
                      else: ~p"/cook/multi/task/#{@active_task_id}"
                  }
                  class={[
                    "flex items-center gap-2 px-3 py-2 rounded-xl text-[11px] font-bold transition-colors",
                    if(@mode == "standard",
                      do: "bg-coral/10 text-coral",
                      else: "text-gray-600 hover:bg-linen"
                    )
                  ]}
                  phx-click={JS.hide(to: "#hero-settings-menu")}
                >
                  <.icon name="hero-list-bullet" class="size-3" /> Standard
                </.link>
                <.link
                  patch={
                    if @slug,
                      do: ~p"/run/#{@slug}/task/#{@active_task_id}",
                      else: ~p"/run/multi/task/#{@active_task_id}"
                  }
                  class={[
                    "flex items-center gap-2 px-3 py-2 rounded-xl text-[11px] font-bold transition-colors mt-1",
                    if(@mode == "focus",
                      do: "bg-coral/10 text-coral",
                      else: "text-gray-600 hover:bg-linen"
                    )
                  ]}
                  phx-click={JS.hide(to: "#hero-settings-menu")}
                >
                  <.icon name="hero-eye" class="size-3" /> Focus
                </.link>
              </div>
            </div>
          </div>
        </div>
      </div>

      <%!-- Ingredients Area (Fixed Height) --%>
      <div class="flex-1 flex items-center justify-center px-4 overflow-hidden py-4">
        <div class="max-w-3xl w-full">
          <div class="flex flex-wrap justify-center gap-2 max-h-[80px] overflow-y-auto no-scrollbar">
            <div :if={@active_ingredients == []} class="flex items-center gap-2 text-gray-300">
              <span class="text-[10px] font-bold uppercase tracking-widest italic">
                Ready for the next step
              </span>
            </div>
            <%= for ing <- @active_ingredients do %>
              <div class="bg-white/60 border border-white/80 px-4 py-2 rounded-2xl flex items-center gap-3 shadow-sm animate-in fade-in slide-in-from-bottom-2 duration-500">
                <span class="text-xs font-bold text-gray-900 uppercase tracking-tighter">
                  {ing.name}
                </span>
                <span class="text-[11px] text-coral font-bold border-l border-parchment pl-3">
                  {ing.amount} {ing.unit}
                </span>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <%!-- Playbar Progress (Full Width, Shorter) --%>
      <div class="w-full shrink-0">
        <div class="h-4 w-full bg-coral/10 relative overflow-hidden shadow-inner">
          <%!-- Progress Fill --%>
          <div
            id="global-progress-bar"
            class="absolute top-0 left-0 h-full bg-coral/90 transition-all duration-700 ease-out"
            style={"width: #{@progress}%"}
          >
          </div>

          <%!-- Centered Time --%>
          <div class="absolute inset-0 flex items-center justify-center pointer-events-none">
            <div
              id="time-remaining-display"
              class="text-[9px] font-bold tracking-[0.1em] uppercase text-gray-900"
            >
              {@remaining_text || "Starting..."}
            </div>
          </div>
        </div>
      </div>
    </header>
    """
  end

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :any
  attr :variant, :string, values: ~w(primary)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{"primary" => "btn-primary", nil => "btn-primary btn-soft"}

    assigns =
      assign_new(assigns, :class, fn ->
        ["btn", Map.fetch!(variants, assigns[:variant])]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as radio, are best
  written directly in your templates.

  ## Examples

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  ```

  ## Select type

  When using `type="select"`, you must pass the `options` and optionally
  a `value` to mark which option should be preselected.

  ```heex
  <.input field={@form[:user_type]} type="select" options={["Admin": "admin", "User": "user"]} />
  ```

  For more information on what kind of data can be passed to `options` see
  [`options_for_select`](https://hexdocs.pm/phoenix_html/Phoenix.HTML.Form.html#options_for_select/2).
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="fieldset mb-2">
      <label>
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <span class="label">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={@class || "checkbox checkbox-sm"}
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[@class || "w-full select", @errors != [] && (@error_class || "select-error")]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || "w-full textarea",
            @errors != [] && (@error_class || "textarea-error")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || "w-full input",
            @errors != [] && (@error_class || "input-error")
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error">
      <.icon name="hero-exclamation-circle" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-base-content/70">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="table table-zebra">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          <th :if={@action != []}>
            <span class="sr-only">{gettext("Actions")}</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li :for={item <- @item} class="list-row">
        <div class="list-col-grow">
          <div class="font-bold">{item.title}</div>
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"
  attr :rest, :global

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} {@rest} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(RouxLiveWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(RouxLiveWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
