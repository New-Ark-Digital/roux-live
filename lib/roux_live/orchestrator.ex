defmodule RouxLive.Orchestrator do
  defmodule Task do
    @enforce_keys [:id, :text, :recipe_title, :work_m, :wait_m, :phase, :type]
    defstruct [
      :id,
      :text,
      :recipe_title,
      :work_m,
      :wait_m,
      :phase,
      :type,
      :resources,
      :start_at_m,
      :recipe_slug
    ]
  end

  def generate_phases(recipes) do
    # 1. Unified Mise en Place (Phase 1)
    mise_en_place = aggregate_prep(recipes)

    # 2. Extract All Instruction Tasks
    all_raw_tasks =
      Enum.flat_map(recipes, fn recipe ->
        Enum.map(recipe.steps, fn step ->
          %Task{
            id: "#{recipe.slug}-#{step.id}",
            text: step.text,
            recipe_title: recipe.title,
            recipe_slug: recipe.slug,
            work_m: step.work_m,
            wait_m: step.wait_m,
            resources: step.resources || [],
            type: step.type,
            # To be assigned
            phase: nil
          }
        end)
      end)

    # 3. Categorize into strict phases
    # Phase 2: Long-Lead
    long_lead = Enum.filter(all_raw_tasks, &(&1.type == "long-lead"))

    # Phase 3: Setup
    setup = Enum.filter(all_raw_tasks, &(&1.type == "setup"))

    # Phase 4: Action (everything else)
    action_raw = Enum.filter(all_raw_tasks, &(&1.type not in ["long-lead", "setup"]))

    # 4. Build Interleaved Timeline for Action Phase
    action_timeline = build_resource_aware_timeline(action_raw)

    warnings = generate_warnings(all_raw_tasks)

    %{
      pre_prep: [],
      mise_en_place: mise_en_place,
      long_lead: long_lead,
      setup: setup,
      action: action_timeline,
      warnings: warnings
    }
  end

  defp aggregate_prep(recipes) do
    recipes
    |> Enum.flat_map(fn r ->
      Enum.filter(r.ingredients, & &1.requires_prep)
      |> Enum.map(&{&1, r.title})
    end)
    |> Enum.group_by(fn {ing, _} -> String.downcase(ing.name) end)
    |> Enum.map(fn {name, items} ->
      details =
        Enum.map_join(items, ", ", fn {ing, title} -> "#{ing.amount} #{ing.unit} for #{title}" end)

      %Task{
        id: "agg-prep-#{name}",
        text: "Prep #{String.capitalize(name)}: #{details}",
        recipe_title: "Unified Mise en Place",
        recipe_slug: "multi",
        work_m: length(items) * 2,
        wait_m: 0,
        phase: :mise_en_place,
        type: "prep",
        resources: []
      }
    end)
    |> Enum.sort_by(& &1.text)
  end

  defp build_resource_aware_timeline([]), do: []

  defp build_resource_aware_timeline(tasks) do
    by_recipe = Enum.group_by(tasks, & &1.recipe_slug)

    recipe_metrics =
      Enum.map(by_recipe, fn {slug, r_tasks} ->
        duration = Enum.reduce(r_tasks, 0, fn t, acc -> acc + t.work_m + t.wait_m end)
        {slug, %{total: duration, tasks: r_tasks}}
      end)
      |> Map.new()

    max_duration =
      if map_size(recipe_metrics) > 0,
        do: Enum.map(Map.values(recipe_metrics), & &1.total) |> Enum.max(),
        else: 0

    Enum.reduce(Map.keys(recipe_metrics), [], fn slug, current_schedule ->
      metrics = recipe_metrics[slug]
      preferred_start = max_duration - metrics.total

      {new_tasks, _} =
        Enum.reduce(metrics.tasks, {[], preferred_start}, fn t, {acc, earliest_start} ->
          start_time = find_available_slot(t, earliest_start, current_schedule)
          task_with_time = %{t | start_at_m: start_time}
          {acc ++ [task_with_time], start_time + t.work_m + t.wait_m}
        end)

      current_schedule ++ new_tasks
    end)
    |> Enum.sort_by(&{&1.start_at_m, &1.work_m})
  end

  defp find_available_slot(task, preferred_start, schedule) do
    conflicts =
      Enum.any?(schedule, fn existing ->
        t_start = preferred_start
        t_end = preferred_start + task.work_m
        e_start = existing.start_at_m
        e_end = existing.start_at_m + existing.work_m

        work_overlap = overlap?(t_start, t_end, e_start, e_end)

        resource_overlap =
          Enum.any?(task.resources || [], fn res -> res in (existing.resources || []) end) and
            overlap?(t_start, t_end, e_start, e_end)

        work_overlap or resource_overlap
      end)

    if conflicts do
      find_available_slot(task, preferred_start + 1, schedule)
    else
      preferred_start
    end
  end

  defp overlap?(s1, e1, s2, e2) do
    max(s1, s2) < min(e1, e2)
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
      [
        "⚠️ Multiple oven temperatures detected: #{Enum.map_join(oven_tasks, ", ", fn {title, [temp]} -> "#{title} (#{temp})" end)}. You may need to cook these sequentially."
      ]
    else
      []
    end
  end
end
