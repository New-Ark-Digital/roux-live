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
      :recipe_slug,
      :is_utility
    ]
  end

  @kitchen_profiles %{
    "minimalist" => %{burners: 2, ovens: 1, prep_areas: 1},
    "standard" => %{burners: 4, ovens: 1, prep_areas: 2},
    "chef" => %{burners: 6, ovens: 2, prep_areas: 10}
  }

  def generate_phases(recipes, kitchen_type \\ "standard") do
    profile = Map.get(@kitchen_profiles, kitchen_type, @kitchen_profiles["standard"])

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
            phase: nil,
            is_utility: false
          }
        end)
      end)

    # 3. Categorize into strict phases
    long_lead = Enum.filter(all_raw_tasks, &(&1.type == "long-lead"))
    setup = Enum.filter(all_raw_tasks, &(&1.type == "setup"))
    action_raw = Enum.filter(all_raw_tasks, &(&1.type not in ["long-lead", "setup"]))

    # 4. Build Resource-Aware Timeline
    action_timeline = build_resource_aware_timeline(action_raw, profile, kitchen_type)

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
        resources: [],
        is_utility: false
      }
    end)
    |> Enum.sort_by(& &1.text)
  end

  defp build_resource_aware_timeline([], _profile, _kitchen_type), do: []

  defp build_resource_aware_timeline(tasks, profile, kitchen_type) do
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

    schedule_recipes(
      Map.keys(recipe_metrics),
      recipe_metrics,
      max_duration,
      profile,
      kitchen_type,
      []
    )
  end

  defp schedule_recipes([], _metrics, _max_duration, _profile, _kitchen_type, schedule),
    do: Enum.sort_by(schedule, &{&1.start_at_m, &1.work_m})

  defp schedule_recipes([slug | rest], metrics, max_duration, profile, kitchen_type, schedule) do
    recipe_info = metrics[slug]
    preferred_start = max_duration - recipe_info.total

    {_new_tasks, updated_schedule} =
      Enum.reduce(recipe_info.tasks, {[], schedule}, fn t, {acc, current_schedule} ->
        earliest_possible =
          case List.last(acc) do
            nil -> preferred_start
            prev -> prev.start_at_m + prev.work_m + prev.wait_m
          end

        start_time = find_available_slot(t, earliest_possible, current_schedule, profile)

        {cleanup_tasks, _} =
          check_and_inject_cleanup(t, start_time, current_schedule, kitchen_type)

        task_with_time = %{t | start_at_m: start_time}

        {acc ++ cleanup_tasks ++ [task_with_time],
         current_schedule ++ cleanup_tasks ++ [task_with_time]}
      end)

    schedule_recipes(rest, metrics, max_duration, profile, kitchen_type, updated_schedule)
  end

  defp find_available_slot(task, start_at, schedule, profile) do
    task_resource_types = categorize_resources(task.resources)

    has_conflict =
      Enum.any?(schedule, fn existing ->
        t_active_start = start_at
        t_active_end = start_at + task.work_m

        e_active_start = existing.start_at_m
        e_active_end = existing.start_at_m + existing.work_m

        buffer = if task.type == "terminal" or existing.type == "terminal", do: 2, else: 0

        chef_lock_conflict =
          overlap?(t_active_start - buffer, t_active_end + buffer, e_active_start, e_active_end)

        name_conflict =
          Enum.any?(task.resources || [], fn res -> res in (existing.resources || []) end) and
            overlap?(
              start_at,
              start_at + task.work_m + task.wait_m,
              existing.start_at_m,
              existing.start_at_m + existing.work_m + existing.wait_m
            )

        chef_lock_conflict or name_conflict
      end)

    capacity_conflict =
      if not has_conflict do
        window_start = start_at
        window_end = start_at + task.work_m + task.wait_m

        overlapping_tasks =
          Enum.filter(schedule, fn e ->
            overlap?(window_start, window_end, e.start_at_m, e.start_at_m + e.work_m + e.wait_m)
          end)

        burner_conflict =
          if :burner in task_resource_types do
            in_use =
              overlapping_tasks
              |> Enum.filter(fn e -> :burner in categorize_resources(e.resources) end)
              |> length()

            in_use >= profile.burners
          else
            false
          end

        oven_conflict =
          if :oven in task_resource_types do
            in_use =
              overlapping_tasks
              |> Enum.filter(fn e -> :oven in categorize_resources(e.resources) end)
              |> length()

            in_use >= profile.ovens
          else
            false
          end

        burner_conflict or oven_conflict
      else
        false
      end

    if has_conflict or capacity_conflict do
      find_available_slot(task, start_at + 1, schedule, profile)
    else
      start_at
    end
  end

  defp categorize_resources(resources) do
    Enum.map(resources || [], fn
      res when res in ["stovetop", "skillet", "pot", "pan"] -> :burner
      res when res in ["oven"] -> :oven
      _ -> :prep
    end)
    |> Enum.uniq()
  end

  defp check_and_inject_cleanup(task, start_time, schedule, kitchen_type) do
    if kitchen_type == "chef" do
      {[], schedule}
    else
      resources_to_clean =
        Enum.filter(task.resources || [], fn res ->
          # Find the most recent use of this specific resource
          last_use =
            schedule
            |> Enum.filter(&(res in (&1.resources || [])))
            |> Enum.max_by(& &1.start_at_m, fn -> nil end)

          # Only clean if the last user was a different recipe AND it wasn't already a cleanup task
          last_use != nil and last_use.recipe_slug != task.recipe_slug and not last_use.is_utility
        end)

      if resources_to_clean != [] do
        cleanup_task = %Task{
          id: "cleanup-#{task.id}-#{Enum.join(resources_to_clean, "-")}",
          text:
            "Cleanup: #{Enum.join(resources_to_clean, ", ")} (Transition to #{task.recipe_title})",
          recipe_title: "Kitchen Maintenance",
          recipe_slug: "utility",
          work_m: 3,
          wait_m: 0,
          phase: :action,
          type: "utility",
          resources: resources_to_clean,
          start_at_m: max(0, start_time - 3),
          is_utility: true
        }

        {[cleanup_task], schedule}
      else
        {[], schedule}
      end
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
