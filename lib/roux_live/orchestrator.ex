defmodule RouxLive.Orchestrator do
  defmodule Task do
    @enforce_keys [:id, :text, :recipe_title, :work_m, :wait_m, :phase]
    defstruct [:id, :text, :recipe_title, :work_m, :wait_m, :phase, :resources]
  end

  def generate_phases(recipes) do
    all_raw_tasks = 
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

    # Automatic Ingredient Prep Tasks
    auto_prep_tasks = 
      recipes
      |> Enum.flat_map(fn recipe ->
        recipe.ingredients
        |> Enum.filter(&(&1.requires_prep))
        |> Enum.map(fn ing ->
          %Task{
            id: "auto-prep-#{recipe.slug}-#{ing.id}",
            text: "Prep #{ing.name}: #{ing.note || "process as needed"}",
            recipe_title: recipe.title,
            work_m: 2, # Default 2 mins for prep
            wait_m: 0,
            phase: :mise_en_place,
            resources: []
          }
        end)
      end)

    # Pre-prep tasks from ingredients (lead time)
    pre_prep_tasks = 
      recipes
      |> Enum.flat_map(fn recipe ->
        recipe.ingredients
        |> Enum.filter(&(&1.lead_time_m > 0))
        |> Enum.map(fn ing ->
          %Task{
            id: "pre-prep-#{recipe.slug}-#{ing.id}",
            text: "Advance Prep: #{ing.name} (#{ing.note || "required lead time"})",
            recipe_title: recipe.title,
            work_m: 0,
            wait_m: ing.lead_time_m,
            phase: :pre_prep,
            resources: []
          }
        end)
      end)

    all_tasks = all_raw_tasks ++ auto_prep_tasks ++ pre_prep_tasks

    # Phases
    pre_prep = Enum.filter(all_tasks, &(&1.phase == :pre_prep))
    mise_en_place = Enum.filter(all_tasks, &(&1.phase == :mise_en_place))
    setup = Enum.filter(all_tasks, &(&1.phase == :setup))
    
    # Interleave the Action phase
    action_raw = Enum.filter(all_tasks, &(&1.phase == :action))
    action_interleaved = interleave_tasks(action_raw)

    warnings = generate_warnings(all_tasks)

    %{
      pre_prep: pre_prep,
      mise_en_place: mise_en_place,
      setup: setup,
      action: action_interleaved,
      warnings: warnings
    }
  end

  defp generate_warnings(tasks) do
    # Simple check for multiple oven temperatures needed at once
    # This is a bit complex without full time simulation, but we can look for
    # tasks in the 'action' phase that mention temperatures.
    
    oven_tasks = 
      tasks 
      |> Enum.filter(&Enum.member?(&1.resources, "oven"))
      |> Enum.map(fn t -> 
        temp = Regex.run(~r/\d{3}°F/, t.text)
        {t.recipe_title, temp}
      end)
      |> Enum.filter(fn {_, temp} -> temp != nil end)
      |> Enum.uniq()

    if length(oven_tasks) > 1 do
      ["⚠️ Multiple oven temperatures detected: #{Enum.map_join(oven_tasks, ", ", fn {title, [temp]} -> "#{title} (#{temp})" end)}. You may need to cook these sequentially."]
    else
      []
    end
  end

  defp determine_phase(step) do
    text = String.downcase(step.text)
    cond do
      step.wait_m >= 60 -> :pre_prep
      String.contains?(text, ["preheat", "boil", "bring to temperature"]) -> :setup
      step.wait_m == 0 and not Enum.any?(step.resources, &(&1 in ["oven", "stovetop", "grill", "skillet"])) -> :mise_en_place
      true -> :action
    end
  end

  defp interleave_tasks([]), do: []
  defp interleave_tasks(tasks) do
    # Simple interleaving: 
    # 1. Sort by recipe (to keep relative order within recipe)
    # 2. In a real DAG we'd use dependencies, but here we'll keep it simple for now
    # but try to interleave work into wait times.
    
    # For now, let's just ensure we don't have all Recipe A then all Recipe B
    # if Recipe A has a long wait at the start.
    
    # Better: Group by recipe, then zip them
    tasks_by_recipe = Enum.group_by(tasks, & &1.recipe_title) |> Map.values()
    
    interleave_lists(tasks_by_recipe, [])
  end

  defp interleave_lists([], acc), do: Enum.reverse(acc)
  defp interleave_lists(lists, acc) do
    # Take one from each non-empty list
    {heads, remainders} = 
      lists
      |> Enum.map(fn
        [h | t] -> {h, t}
        [] -> {nil, []}
      end)
      |> Enum.unzip()

    new_acc = Enum.reject(heads, &is_nil/1) ++ acc
    new_lists = Enum.reject(remainders, &(&1 == []))
    
    interleave_lists(new_lists, new_acc)
  end
end
