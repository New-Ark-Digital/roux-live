defmodule RouxLive.Orchestrator do
  defmodule Task do
    @enforce_keys [:id, :text, :recipe_title, :work_m, :wait_m, :phase]
    defstruct [:id, :text, :recipe_title, :work_m, :wait_m, :phase, :resources, :start_at_m]
  end

  def generate_phases(recipes) do
    # 1. Unified Mise en Place (Phase 1)
    mise_en_place = aggregate_prep(recipes)

    # 2. Instructions Extraction
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

    # 3. Categorization
    pre_prep = Enum.filter(all_raw_tasks, &(&1.phase == :pre_prep))
    long_lead = Enum.filter(all_raw_tasks, &(&1.phase == :long_lead))
    setup = Enum.filter(all_raw_tasks, &(&1.phase == :setup))
    
    # 4. Critical Path Interlock (Phase 4)
    action_raw = Enum.filter(all_raw_tasks, &(&1.phase == :action))
    action_interleaved = build_deterministic_timeline(action_raw)

    warnings = generate_warnings(all_raw_tasks)

    %{
      pre_prep: pre_prep,
      mise_en_place: mise_en_place,
      long_lead: long_lead,
      setup: setup,
      action: action_interleaved,
      warnings: warnings
    }
  end

  defp aggregate_prep(recipes) do
    recipes
    |> Enum.flat_map(fn r -> 
      Enum.filter(r.ingredients, & &1.requires_prep) 
      |> Enum.map(& {&1, r.title})
    end)
    |> Enum.group_by(fn {ing, _} -> String.downcase(ing.name) end)
    |> Enum.map(fn {name, items} ->
      details = Enum.map_join(items, ", ", fn {ing, title} -> "#{ing.amount} #{ing.unit} for #{title}" end)
      
      %Task{
        id: "agg-prep-#{name}",
        text: "Prep #{String.capitalize(name)}: #{details}",
        recipe_title: "Unified Mise en Place",
        work_m: length(items) * 2,
        wait_m: 0,
        phase: :mise_en_place,
        resources: []
      }
    end)
    |> Enum.sort_by(& &1.text)
  end

  defp determine_phase(step) do
    text = String.downcase(step.text)
    cond do
      step.wait_m >= 60 -> :pre_prep
      step.wait_m > 0 and not Enum.any?(step.resources, &(&1 in ["oven", "stovetop", "skillet"])) -> :long_lead
      String.contains?(text, ["preheat", "boil", "bring to temperature"]) -> :setup
      true -> :action
    end
  end

  defp build_deterministic_timeline([]), do: []
  defp build_deterministic_timeline(tasks) do
    # Group by recipe
    by_recipe = Enum.group_by(tasks, & &1.recipe_title)
    
    # Calculate durations for reverse scheduling
    recipe_durations = 
      Enum.map(by_recipe, fn {title, r_tasks} ->
        duration = Enum.reduce(r_tasks, 0, fn t, acc -> acc + t.work_m + t.wait_m end)
        {title, duration}
      end) |> Map.new()

    max_duration = Map.values(recipe_durations) |> Enum.max()

    # Position tasks anchored to common finish time
    positioned_tasks = 
      Enum.flat_map(by_recipe, fn {title, r_tasks} ->
        # Calculate start offset so this recipe ends at max_duration
        offset = max_duration - Map.get(recipe_durations, title)
        
        {final_tasks, _} = Enum.reduce(r_tasks, {[], offset}, fn t, {acc, current_time} ->
          task_with_time = %{t | start_at_m: current_time}
          {acc ++ [task_with_time], current_time + t.work_m + t.wait_m}
        end)
        final_tasks
      end)

    # Simple interleaving sort
    # We sort by start time, but if times are equal, we prioritize shorter tasks 
    # or follow a consistent recipe order.
    Enum.sort_by(positioned_tasks, & {&1.start_at_m, &1.work_m})
  end

  defp generate_warnings(tasks) do
    oven_tasks = 
      tasks 
      |> Enum.filter(&Enum.member?(&1.resources || [], "oven"))
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
end
