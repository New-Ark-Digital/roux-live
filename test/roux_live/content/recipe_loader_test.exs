defmodule RouxLive.Content.RecipeLoaderTest do
  use ExUnit.Case, async: true
  alias RouxLive.Content.RecipeLoader

  @recipes_dir Path.join(:code.priv_dir(:roux_live), "content/recipes")

  test "load!/1 loads the chocolate-chip-cookies recipe" do
    recipe = RecipeLoader.load!("chocolate-chip-cookies")
    assert recipe.title == "Chocolate Chip Cookies"
    assert recipe.slug == "chocolate-chip-cookies"
    assert length(recipe.ingredients) == 9
    assert length(recipe.steps) == 9
  end

  test "validation fails on unknown ingredient ref" do
    slug = "invalid-ref"
    path = Path.join(@recipes_dir, "#{slug}.yml")
    
    yaml = """
    schema: "recipe/simple-v1"
    id: "invalid-ref"
    slug: "invalid-ref"
    title: "Invalid Ref"
    ingredients:
      - id: "flour"
        name: "Flour"
        amount: 1
        unit: "cup"
        note: null
    steps:
      - id: "step-1"
        text: "Use sugar"
        uses: ["sugar"]
    """
    
    File.write!(path, yaml)
    
    assert_raise RuntimeError, ~r/references unknown ingredient ID: sugar/, fn ->
      RecipeLoader.load!(slug)
    end
    
    File.rm!(path)
  end

  test "validation fails on duplicate ingredient IDs" do
    slug = "dup-ids"
    path = Path.join(@recipes_dir, "#{slug}.yml")
    
    yaml = """
    schema: "recipe/simple-v1"
    id: "dup-ids"
    slug: "dup-ids"
    title: "Dup IDs"
    ingredients:
      - id: "flour"
        name: "Flour 1"
        amount: 1
        unit: "cup"
        note: null
      - id: "flour"
        name: "Flour 2"
        amount: 1
        unit: "cup"
        note: null
    steps: []
    """
    
    File.write!(path, yaml)
    
    assert_raise RuntimeError, ~r/Ingredient IDs must be unique/, fn ->
      RecipeLoader.load!(slug)
    end
    
    File.rm!(path)
  end
end
