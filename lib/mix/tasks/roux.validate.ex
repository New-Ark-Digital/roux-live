defmodule Mix.Tasks.Roux.Validate do
  use Mix.Task

  @shortdoc "Validates Roux recipe YAML files against the current schema"

  alias RouxLive.Content.RecipeLoader

  @impl Mix.Task
  def run(args) do
    # Ensure the app is loaded to access structs and loader
    Mix.Task.run("app.start")

    case args do
      [] ->
        validate_all()

      paths ->
        Enum.each(paths, &validate_file/1)
    end
  end

  defp validate_all do
    dir = Path.join(:code.priv_dir(:roux_live), "content/recipes")

    dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".yml"))
    |> Enum.map(fn filename -> Path.join(dir, filename) end)
    |> Enum.each(&validate_file/1)
  end

  defp validate_file(path) do
    IO.puts("Validating #{Path.basename(path)}...")

    case YamlElixir.read_from_file(path) do
      {:ok, data} ->
        try do
          # Use existing loader validation logic
          # We might want to expose it or duplicate it here for better errors
          recipe = RecipeLoader.load!(data["slug"] || Path.rootname(Path.basename(path)))

          # Perform additional logic checks
          check_logical_consistency(recipe, data)

          IO.puts("✅ Valid")
        rescue
          e ->
            IO.puts("❌ Validation failed: #{Exception.message(e)}")
            System.at_exit(fn _ -> exit({:shutdown, 1}) end)
        end

      {:error, reason} ->
        IO.puts("❌ YAML Error: #{inspect(reason)}")
        System.at_exit(fn _ -> exit({:shutdown, 1}) end)
    end
  end

  defp check_logical_consistency(recipe, _data) do
    # Check for ingredients not used in any step
    used_ingredient_ids =
      recipe.steps
      |> Enum.flat_map(& &1.uses)
      |> Enum.uniq()

    all_ingredient_ids = Enum.map(recipe.ingredients, & &1.id)

    orphans = all_ingredient_ids -- used_ingredient_ids

    if orphans != [] do
      IO.puts(
        "⚠️  Warning: Orphan ingredients (defined but not used in any step): #{Enum.join(orphans, ", ")}"
      )
    end

    # Check for empty steps
    if recipe.steps == [] do
      raise "Recipe has no steps"
    end

    # Check for schema version
    # (Already handled in RecipeLoader.validate!)
  end
end
