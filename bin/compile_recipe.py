#!/usr/bin/env python3
import sys
import os
import subprocess
import argparse


def run_opencode(prompt, context_file=None):
    cmd = ["opencode", "--prompt", prompt]
    if context_file:
        cmd.extend(["--file", context_file])

    # We use check_output to get the result
    # In a real environment, opencode might be interactive,
    # but we assume it can be used like this for automated tasks.
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error calling opencode: {result.stderr}")
        sys.exit(1)
    return result.stdout


def main():
    parser = argparse.ArgumentParser(
        description="Iteratively compile a recipe into Roux YAML format."
    )
    parser.add_argument("input_file", help="Path to raw recipe text or partial YAML")
    parser.add_argument("--output", "-o", help="Output YAML path", default="recipe.yml")
    args = parser.parse_args()

    with open(args.input_file, "r") as f:
        raw_text = f.read()

    print("🚀 Stage 1: Extracting Metadata & Skeleton...")
    prompt = f"""
    Transform this raw recipe text into a Roux YAML skeleton.
    Focus ONLY on: id, slug, title, summary, yield, and total_time.
    Schema: 'recipe/simple-v5.1'
    Include empty placeholders for ingredients and steps.
    
    TEXT:
    {raw_text}
    """
    yaml_content = run_opencode(prompt)
    with open(args.output, "w") as f:
        f.write(yaml_content)

    print("🌿 Stage 2: Normalizing Ingredients & Prep Detection...")
    prompt = f"""
    Update the 'ingredients' list in the provided YAML based on the original raw text.
    Focus ONLY on: name, amount, unit, note, and requires_prep.
    - Set 'requires_prep: true' if the text implies work (e.g. diced, minced).
    - Assign unique IDs like 'f-garlic'.
    - Keep existing metadata.
    
    RAW TEXT:
    {raw_text}
    """
    yaml_content = run_opencode(prompt, context_file=args.output)
    with open(args.output, "w") as f:
        f.write(yaml_content)

    print("⏱️  Stage 3: Sequentializing Steps & Durations...")
    prompt = f"""
    Update the 'steps' list in the provided YAML based on the original raw text.
    Focus ONLY on: discrete steps, work_m (active), wait_m (passive), resources, and type.
    - Break prose into executable steps.
    - 'terminal' type for serving/garnish.
    - 'long-lead' for >30m passive waits.
    - Keep ingredients and metadata intact.
    
    RAW TEXT:
    {raw_text}
    """
    yaml_content = run_opencode(prompt, context_file=args.output)
    with open(args.output, "w") as f:
        f.write(yaml_content)

    print("🔗 Stage 4: Semantic Linking & Grouping...")
    prompt = f"""
    Finalize the YAML by linking ingredients to steps and creating groups.
    Focus ONLY on: 
    - Populate 'uses' lists in steps with ingredient IDs.
    - Create 'ingredient_groups' and 'step_groups'.
    - Add 'notes', 'tags', and 'equipment'.
    - Ensure all ID references are correct.
    
    RAW TEXT:
    {raw_text}
    """
    yaml_content = run_opencode(prompt, context_file=args.output)
    with open(args.output, "w") as f:
        f.write(yaml_content)

    print("✅ Stage 5: Deterministic Validation...")
    result = subprocess.run(
        ["mix", "roux.validate", args.output], capture_output=True, text=True
    )
    print(result.stdout)
    if result.returncode == 0:
        print(f"✨ Successfully compiled to {args.output}")
    else:
        print("❌ Validation failed. Please check the output above.")
        sys.exit(1)


if __name__ == "__main__":
    main()
