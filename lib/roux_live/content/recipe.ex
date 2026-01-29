defmodule RouxLive.Content.Recipe do
  defmodule Yield do
    @enforce_keys [:quantity, :unit]
    defstruct [:quantity, :unit]
  end

  defmodule Time do
    @enforce_keys [:prep_minutes, :cook_minutes, :total_minutes]
    defstruct [:prep_minutes, :cook_minutes, :total_minutes]
  end

  defmodule IngredientGroup do
    @enforce_keys [:id, :title, :ingredient_ids]
    defstruct [:id, :title, :ingredient_ids]
  end

  defmodule Ingredient do
    @enforce_keys [:id, :name, :amount, :unit, :note, :optional]
    defstruct [:id, :name, :amount, :unit, :note, :optional]
  end

  defmodule StepGroup do
    @enforce_keys [:id, :title, :step_ids]
    defstruct [:id, :title, :step_ids]
  end

  defmodule Step do
    @enforce_keys [:id, :text, :uses]
    defstruct [:id, :text, :uses]
  end

  @enforce_keys [:id, :slug, :title, :summary, :yield, :time, :ingredient_groups, :ingredients, :step_groups, :steps, :notes, :tags]
  defstruct [:id, :slug, :title, :summary, :yield, :time, :ingredient_groups, :ingredients, :step_groups, :steps, :notes, :tags]
end
