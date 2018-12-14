defmodule Aoc201814 do
  def run() do
    part1()
    part2()
  end

  defp part1(), do: recipes() |> Stream.drop(306_281) |> Enum.take(10) |> Enum.join("") |> IO.puts()

  defp part2() do
    target_recipes = Enum.map('306281', &(&1 - ?0))
    find_sublist_index(recipes(), target_recipes) |> IO.puts()
  end

  def find_sublist_index(enumerable, sublist) do
    Enum.reduce_while(
      enumerable,
      {sublist, sublist, 0},
      fn
        el, {[el], _sublist, index} -> {:halt, index + 1 - length(sublist)}
        el, {[el | rest], sublist, index} -> {:cont, {rest, sublist, index + 1}}
        el, {_, [el | rest] = sublist, index} -> {:cont, {rest, sublist, index + 1}}
        _el, {_, sublist, index} -> {:cont, {sublist, sublist, index + 1}}
      end
    )
  end

  defp recipes(), do: Stream.resource(&initial_state/0, &next_recipes/1, &destroy_state/1)

  defp initial_state() do
    initial_recipes = [3, 7]
    recipes = :ets.new(:recipes, [:private, read_concurrency: true, write_concurrency: true])
    add_recipes(recipes, initial_recipes)
    {0, 1, recipes, initial_recipes}
  end

  defp destroy_state({_elf1_pos, _elf2_pos, recipes, _new_recipes}), do: :ets.delete(recipes)

  defp next_recipes({elf1_pos, elf2_pos, recipes, previous_new_recipes}) do
    elf1_recipe = recipe_at(recipes, elf1_pos)
    elf2_recipe = recipe_at(recipes, elf2_pos)

    new_recipes =
      case elf1_recipe + elf2_recipe do
        new_recipe when new_recipe < 10 ->
          :ets.insert(recipes, {num_recipes(recipes), new_recipe})
          [new_recipe]

        new_recipe ->
          new_recipes = [1, new_recipe - 10]
          add_recipes(recipes, new_recipes)
          new_recipes
      end

    elf1_pos = rem(elf1_pos + 1 + elf1_recipe, num_recipes(recipes))
    elf2_pos = rem(elf2_pos + 1 + elf2_recipe, num_recipes(recipes))
    {previous_new_recipes, {elf1_pos, elf2_pos, recipes, new_recipes}}
  end

  defp add_recipes(recipes, new_recipes) do
    new_recipes
    |> Stream.with_index(num_recipes(recipes))
    |> Enum.each(fn {recipe, index} -> :ets.insert(recipes, {index, recipe}) end)
  end

  defp num_recipes(recipes), do: :ets.info(recipes, :size)

  defp recipe_at(recipes, position) do
    [{^position, recipe}] = :ets.lookup(recipes, position)
    recipe
  end
end
