defmodule RouxLive.Orchestrator do

  defmodule Task do
    @enforce_keys [:id, :text, :recipe_title, :work_m, :wait_m, :phase]
    defstruct [:id, :text, :recipe_title, :work_m, :wait_m, :phase, :resources]
  end

  def generate_phases(recipes) do
    tasks = 
      Enum.flat_map(recipes, fn recipe ->
        Enum.map(recipe.steps, fn step ->
          %Task{
            id: "#{recipe.slug}-#{step.id}",
            text: step.text,
            recipe_title: recipe.title,
            work_m: step.work_m,
            wait_m: step.wait_m,
            resources: step.resources,
            phase: determine_phase(step)
          }
        end)
      end)

    # Also add pre-prep tasks from ingredients
    prep_tasks = 
      recipes
      |> Enum.flat_map(fn recipe ->
        recipe.ingredients
        |> Enum.filter(&(&1.lead_time_m > 0))
        |> Enum.map(fn ing ->
          %Task{
            id: "prep-#{recipe.slug}-#{ing.id}",
            text: "Prep: #{ing.name} (#{ing.note || "required lead time"})",
            recipe_title: recipe.title,
            work_m: 0,
            wait_m: ing.lead_time_m,
            phase: :pre_prep,
            resources: []
          }
        end)
      end)

    all_tasks = tasks ++ prep_tasks

    %{
      pre_prep: Enum.filter(all_tasks, &(&1.phase == :pre_prep)),
      mise_en_place: Enum.filter(all_tasks, &(&1.phase == :mise_en_place)),
      setup: Enum.filter(all_tasks, &(&1.phase == :setup)),
      action: Enum.filter(all_tasks, &(&1.phase == :action))
    }
  end

  defp determine_phase(step) do
    cond do
      String.contains?(String.downcase(step.text), ["preheat", "boil", "bloom"]) ->
        :setup
      step.work_m > 0 and step.resources == [] ->
        :mise_en_place
      true ->
        :action
    end
  end
end
