defmodule RouxLive.Content.RecipeLoader do
  alias RouxLive.Content.Recipe
  alias RouxLive.Content.Recipe.{Yield, Time, IngredientGroup, Ingredient, Step, StepGroup}

  def load!(slug) do
    path = Path.join(:code.priv_dir(:roux_live), "content/recipes/#{slug}.yml")

    case YamlElixir.read_from_file(path) do
      {:ok, data} ->
        validate!(data)
        to_struct(data)

      {:error, reason} ->
        raise "Failed to load recipe #{slug}: #{inspect(reason)}"
    end
  end

  def list_all do
    dir = Path.join(:code.priv_dir(:roux_live), "content/recipes")
    
    dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".yml"))
    |> Enum.map(fn filename ->
      slug = String.replace(filename, ".yml", "")
      load!(slug)
    end)
  end

  defp validate!(data) do
    if data["schema"] not in ["recipe/simple-v1", "recipe/simple-v2", "recipe/simple-v3"] do
      raise "Unsupported schema: #{data["schema"]}"
    end

    required_fields = ["id", "slug", "title", "ingredients", "steps"]
    for field <- required_fields do
      if is_nil(data[field]) do
        raise "Missing required field: #{field}"
      end
    end

    ingredient_ids = Enum.map(data["ingredients"], & &1["id"])
    if length(Enum.uniq(ingredient_ids)) != length(ingredient_ids) do
      raise "Ingredient IDs must be unique"
    end

    step_ids = Enum.map(data["steps"], & &1["id"])
    if length(Enum.uniq(step_ids)) != length(step_ids) do
      raise "Step IDs must be unique"
    end

    for step <- data["steps"] do
      for ingredient_id <- step["uses"] || [] do
        if ingredient_id not in ingredient_ids do
          raise "Step #{step["id"]} references unknown ingredient ID: #{ingredient_id}"
        end
      end
    end
  end

  defp to_struct(data) do
    %Recipe{
      id: data["id"],
      slug: data["slug"],
      title: data["title"],
      summary: data["summary"],
      yield: %Yield{
        quantity: data["yield"]["quantity"],
        unit: data["yield"]["unit"]
      },
      time: %Time{
        prep_minutes: data["time"]["prep_minutes"],
        cook_minutes: data["time"]["cook_minutes"],
        total_minutes: data["time"]["total_minutes"]
      },
      ingredient_groups: Enum.map(data["ingredient_groups"] || [], fn g ->
        %IngredientGroup{
          id: g["id"],
          title: g["title"],
          ingredient_ids: g["ingredient_ids"]
        }
      end),
      ingredients: Enum.map(data["ingredients"], fn i ->
        %Ingredient{
          id: i["id"],
          name: i["name"],
          amount: i["amount"],
          unit: i["unit"],
          note: i["note"],
          optional: i["optional"] || false,
          lead_time_m: i["lead_time_m"] || 0,
          requires_prep: Map.get(i, "requires_prep", true)
        }
      end),
      step_groups: Enum.map(data["step_groups"] || [], fn g ->
        %StepGroup{
          id: g["id"],
          title: g["title"],
          step_ids: g["step_ids"]
        }
      end),
      steps: Enum.map(data["steps"], fn s ->
        %Step{
          id: s["id"],
          text: s["text"],
          uses: s["uses"] || [],
          work_m: s["work_m"] || 2,
          wait_m: s["wait_m"] || 0,
          resources: s["resources"] || []
        }
      end),
      notes: data["notes"] || [],
      tags: data["tags"] || []
    }
  end
end
