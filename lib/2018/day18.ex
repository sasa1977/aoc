defmodule Aoc201818 do
  def run() do
    IO.inspect(part1())
    IO.inspect(part2())
  end

  defp part1(), do: resource_value(grid_after_minute(10))
  defp part2(), do: resource_value(grid_after_minute(1_000_000_000))

  defp resource_value(grid) do
    resource_frequencies = Aoc.EnumHelper.frequencies(Map.values(grid.map))
    resource_frequencies.trees * resource_frequencies.lumberyard
  end

  defp grid_after_minute(desired_minute) do
    # Finds the grid state after the desired minute using cycle detection.
    Enum.reduce_while(
      all_states() |> Stream.with_index(),
      {%{}, %{}},
      fn
        {grid, ^desired_minute}, _cache ->
          {:halt, grid}

        {grid, current_minute}, {state_to_minute, minute_to_state} ->
          case Map.fetch(state_to_minute, grid) do
            :error ->
              {:cont, {Map.put(state_to_minute, grid, current_minute), Map.put(minute_to_state, current_minute, grid)}}

            {:ok, cycle_start} ->
              # cycle -> compute the desired minute in the cache, and fetch from cache
              cycle_length = current_minute - cycle_start
              {:halt, Map.fetch!(minute_to_state, cycle_start + rem(desired_minute - cycle_start, cycle_length))}
          end
      end
    )
  end

  defp all_states(), do: Stream.iterate(grid(), &next_state/1)

  defp next_state(grid) do
    map =
      for x <- 0..(grid.size - 1),
          y <- 0..(grid.size - 1),
          pos = {x, y},
          into: %{},
          do: {pos, next_element(grid, pos)}

    %{grid | map: map}
  end

  defp next_element(grid, pos) do
    neighbours = Map.merge(%{trees: 0, lumberyard: 0, ground: 0}, Aoc.EnumHelper.frequencies(neighbours(grid, pos)))

    case element_at(grid, pos) do
      :ground -> if neighbours.trees >= 3, do: :trees, else: :ground
      :trees -> if neighbours.lumberyard >= 3, do: :lumberyard, else: :trees
      :lumberyard -> if neighbours.lumberyard >= 1 and neighbours.trees >= 1, do: :lumberyard, else: :ground
    end
  end

  defp neighbours(grid, {x, y}) do
    for x_offset <- -1..1,
        y_offset <- -1..1,
        x_offset != 0 or y_offset != 0,
        x = x + x_offset,
        y = y + y_offset,
        x >= 0 and x < grid.size and y >= 0 and y < grid.size,
        do: element_at(grid, {x, y})
  end

  defp element_at(grid, pos), do: Map.fetch!(grid.map, pos)

  defp grid() do
    map =
      Aoc.input_lines(2018, 18)
      |> Stream.map(&to_charlist/1)
      |> Stream.with_index()
      |> Stream.flat_map(&elements/1)
      |> Map.new()

    %{map: map, size: map |> Map.size() |> :math.sqrt() |> round()}
  end

  defp elements({chars, y}),
    do: chars |> Stream.with_index() |> Stream.map(fn {char, x} -> {{x, y}, parse_element(char)} end)

  defp parse_element(?.), do: :ground
  defp parse_element(?|), do: :trees
  defp parse_element(?#), do: :lumberyard
end
