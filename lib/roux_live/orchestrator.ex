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
      :is_utility,
      :wait_details,
      :uses,
      # Map of recipe_title => details
      :prep_breakdown
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
    # Ensure even single recipes get their prep extracted if marked
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
            is_utility: false,
            wait_details: step.wait_details,
            uses: step.uses || [],
            prep_breakdown: nil
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
      # detailed breakdown for unified display
      prep_breakdown =
        Map.new(items, fn {ing, title} ->
          {title, "#{ing.amount} #{ing.unit}"}
        end)

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
        is_utility: false,
        wait_details: nil,
        uses: Enum.map(items, fn {ing, _} -> ing.id end),
        prep_breakdown: prep_breakdown
      }
    end)
    |> Enum.sort_by(& &1.text)
  end

  defp build_resource_aware_timeline([], _profile, _kitchen_type), do: []

  defp build_resource_aware_timeline(tasks, profile, kitchen_type) do
    by_recipe = Enum.group_by(tasks, & &1.recipe_slug)

    recipe_metrics =
      Enum.map(by_recipe, fn {slug, r_tasks} ->
        # Effective duration: terminals don't block the next task starting, but they are linear
        duration = Enum.reduce(r_tasks, 0, fn t, acc -> acc + t.work_m + t.wait_m end)
        {slug, %{total: duration, tasks: r_tasks}}
      end)
      |> Map.new()

    # Anchor the finish line at the end of the longest recipe
    max_duration =
      if map_size(recipe_metrics) > 0,
        do: Enum.map(Map.values(recipe_metrics), & &1.total) |> Enum.max(),
        else: 0

    # Sort recipes so the longest (anchor) is scheduled first
    sorted_slugs =
      Map.keys(recipe_metrics) |> Enum.sort_by(fn slug -> -recipe_metrics[slug].total end)

    schedule_recipes(sorted_slugs, recipe_metrics, max_duration, profile, kitchen_type, [])
  end

  defp schedule_recipes([], _metrics, _max_duration, _profile, _kitchen_type, schedule),
    do: Enum.sort_by(schedule, &{&1.start_at_m, &1.work_m})

  defp schedule_recipes([slug | rest], metrics, max_duration, profile, kitchen_type, schedule) do
    recipe_info = metrics[slug]

    # Preferred start time to finish at max_duration
    # However, we'll try to find the EARLIEST available slot that still allows finishing close to max_duration
    # but respects the linear order of the recipe.

    {_new_tasks, updated_schedule} =
      Enum.reduce(recipe_info.tasks, {[], schedule}, fn t, {acc, current_schedule} ->
        # Calculate earliest possible start based on previous task in THIS recipe
        # If it's the first task, it could potentially start at 0 if slots allow
        earliest_possible =
          case List.last(acc) do
            nil -> 0
            prev -> prev.start_at_m + prev.work_m + prev.wait_m
          end

        # Find the first available slot for the work_m part
        start_time = find_available_slot(t, earliest_possible, current_schedule, profile)

        # Inject cleanup if needed
        {cleanup_tasks, earliest_after_cleanup} =
          maybe_prepare_cleanup(t, start_time, current_schedule, kitchen_type, profile)

        # Recalculate start_time if cleanup pushed it
        final_start =
          find_available_slot(
            t,
            earliest_after_cleanup,
            current_schedule ++ cleanup_tasks,
            profile
          )

        task_with_time = %{t | start_at_m: final_start}

        {acc ++ cleanup_tasks ++ [task_with_time],
         current_schedule ++ cleanup_tasks ++ [task_with_time]}
      end)

    # After scheduling a recipe, we might need to shift it to align with the anchor end time
    # but for now let's keep the forward-scheduling logic as it's more robust against conflicts.
    # We can refine the 'preferred_start' later to push shorter recipes as late as possible.

    schedule_recipes(rest, metrics, max_duration, profile, kitchen_type, updated_schedule)
  end

  defp find_available_slot(task, start_at, schedule, profile) do
    # 1. Chef Attention (Lock): can't do two work_m blocks at once
    # 2. Resource Capacity (Burners, Ovens)
    # 3. Terminal Safety Buffer (2m)

    task_resource_types = categorize_resources(task.resources)

    has_conflict =
      Enum.any?(schedule, fn existing ->
        # Proposed work window
        t_work_start = start_at
        t_work_end = start_at + task.work_m

        # Existing work window
        e_work_start = existing.start_at_m
        e_work_end = existing.start_at_m + existing.work_m

        # 1. Chef Lock Conflict
        # If task has work_m > 0 and existing has work_m > 0, they can't overlap
        chef_lock_conflict =
          task.work_m > 0 and existing.work_m > 0 and
            overlap?(t_work_start, t_work_end, e_work_start, e_work_end)

        # 2. Terminal Buffer
        buffer = if task.type == "terminal" or existing.type == "terminal", do: 2, else: 0

        buffer_conflict =
          task.work_m > 0 and existing.work_m > 0 and
            overlap?(t_work_start - buffer, t_work_end + buffer, e_work_start, e_work_end)

        # 3. Blocking Wait Conflict
        # If existing is in a blocking wait, the chef is busy
        blocking_conflict =
          task.work_m > 0 and
            not is_nil(existing.wait_details) and existing.wait_details.blocking and
            overlap?(
              t_work_start,
              t_work_end,
              e_work_start + existing.work_m,
              e_work_start + existing.work_m + existing.wait_m
            )

        chef_lock_conflict or buffer_conflict or blocking_conflict
      end)

    # 4. Resource Capacity Checks (Parallelism for waits is handled by NOT checking them in Chef Lock)
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
        true
      end

    if has_conflict or capacity_conflict do
      find_available_slot(task, start_at + 1, schedule, profile)
    else
      start_at
    end
  end

  defp maybe_prepare_cleanup(task, start_time, schedule, kitchen_type, profile) do
    if kitchen_type == "chef" do
      {[], start_time}
    else
      resources_to_clean =
        Enum.filter(task.resources || [], fn res ->
          last_use =
            schedule
            |> Enum.filter(&(res in (&1.resources || [])))
            |> Enum.max_by(& &1.start_at_m, fn -> nil end)

          last_use != nil and last_use.recipe_slug != task.recipe_slug and not last_use.is_utility
        end)

      if resources_to_clean != [] do
        cleanup_task_raw = %Task{
          id: "cleanup-#{task.id}-#{Enum.join(resources_to_clean, "-")}",
          text: "Cleanup: #{Enum.join(resources_to_clean, ", ")}",
          recipe_title: "Kitchen Maintenance",
          recipe_slug: "utility",
          work_m: 3,
          wait_m: 0,
          phase: :action,
          type: "utility",
          resources: resources_to_clean,
          is_utility: true,
          wait_details: nil
        }

        # Find earliest slot for cleanup starting from thedirty point
        dirty_at =
          schedule
          |> Enum.filter(fn e -> Enum.any?(resources_to_clean, &(&1 in (e.resources || []))) end)
          |> Enum.map(&(&1.start_at_m + &1.work_m))
          |> Enum.max(fn -> 0 end)

        cleanup_start = find_available_slot(cleanup_task_raw, dirty_at, schedule, profile)
        cleanup_task = %{cleanup_task_raw | start_at_m: cleanup_start}

        # +2 for buffer
        {[cleanup_task], max(start_time, cleanup_start + 3 + 2)}
      else
        {[], start_time}
      end
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
