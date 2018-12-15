defmodule Aoc201814 do
  def run() do
    IO.puts(part1())
    IO.puts(part2())
  end

  defp part1(), do: recipes() |> Stream.drop(306_281) |> Enum.take(10) |> Enum.join("")
  defp part2(), do: recipes() |> find_sublist_index(Integer.digits(306_281))

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

  require Record
  Record.defrecord(:state, [:elf1_pos, :elf2_pos, :recipes, :new_recipes])

  defp recipes(), do: Stream.resource(&initial_state/0, &{state(&1, :new_recipes), next_recipes(&1)}, fn _ -> :ok end)

  defp initial_state(), do: state(elf1_pos: 0, elf2_pos: 1, recipes: <<3, 7>>, new_recipes: [3, 7])

  defp next_recipes(state(elf1_pos: elf1_pos, elf2_pos: elf2_pos, recipes: recipes)) do
    elf1_recipe = recipe_at(recipes, elf1_pos)
    elf2_recipe = recipe_at(recipes, elf2_pos)

    {new_recipes, recipes} =
      case elf1_recipe + elf2_recipe do
        new_recipe when new_recipe < 10 ->
          {[new_recipe], <<recipes::binary, new_recipe>>}

        new_recipe ->
          [_, recipe] = new_recipes = [1, new_recipe - 10]
          {new_recipes, <<recipes::binary, 1, recipe>>}
      end

    elf1_pos = rem(elf1_pos + 1 + elf1_recipe, num_recipes(recipes))
    elf2_pos = rem(elf2_pos + 1 + elf2_recipe, num_recipes(recipes))

    state(elf1_pos: elf1_pos, elf2_pos: elf2_pos, recipes: recipes, new_recipes: new_recipes)
  end

  defp num_recipes(recipes), do: byte_size(recipes)

  defp recipe_at(recipes, position), do: :binary.at(recipes, position)
end
