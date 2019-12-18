defmodule Aoc201918 do
  def run do
    IO.inspect(part1())
  end

  defp part1() do
    map = map()

    neighbours =
      [map.my_pos | Map.keys(map.keys)]
      |> Stream.map(&{&1, trace(map, &1)})
      |> Map.new()

    {running_min, _visited} = try_paths(map, map.my_pos, neighbours)
    running_min
  end

  defp try_paths(map, at, neighbours, acquired_keys \\ MapSet.new(), steps \\ 0, running_min \\ nil, visited \\ %{}) do
    cond do
      not is_nil(running_min) and steps >= running_min ->
        {running_min, visited}

      MapSet.size(acquired_keys) == map_size(map.keys) ->
        {min(steps, running_min || steps + 1), visited}

      Enum.any?(
        Map.get(visited, at, []),
        fn {seen_keys, seen_steps} -> MapSet.subset?(acquired_keys, seen_keys) and seen_steps <= steps end
      ) ->
        {running_min, visited}

      true ->
        visited = Map.update(visited, at, [{acquired_keys, steps}], &[{acquired_keys, steps} | &1])

        neighbours
        |> Map.fetch!(at)
        |> Stream.map(&target_key(&1, acquired_keys))
        |> Stream.reject(&is_nil/1)
        |> Enum.sort_by(& &1.distance)
        |> Enum.reduce(
          {running_min, visited},
          fn node, {best_path, visited} ->
            steps = steps + node.distance
            acquired_keys = MapSet.put(acquired_keys, node.door)
            try_paths(map, node.at, neighbours, acquired_keys, steps, best_path, visited)
          end
        )
    end
  end

  defp target_key([], _), do: nil

  defp target_key([{:key, key} | rest], acquired_keys) do
    if MapSet.member?(acquired_keys, key.door),
      do: target_key(rest, acquired_keys),
      else: key
  end

  defp target_key([{:door, door} | rest], acquired_keys) do
    if MapSet.member?(acquired_keys, door),
      do: target_key(rest, acquired_keys),
      else: nil
  end

  defp trace(map, at, steps \\ 0, visited \\ MapSet.new()) do
    visited = MapSet.put(visited, at)

    objects =
      case map do
        %{doors: %{^at => door}} -> [{:door, door}]
        %{keys: %{^at => door}} -> [{:key, %{at: at, door: door, distance: steps}}]
        _ -> []
      end

    for(dx <- -1..1, dy <- -1..1, dx == 0 or dy == 0, {x, y} = at, do: {x + dx, y + dy})
    |> Stream.reject(&MapSet.member?(visited, &1))
    |> Stream.reject(&MapSet.member?(map.walls, &1))
    |> Stream.map(&trace(map, &1, steps + 1, visited))
    |> Enum.concat()
    |> case do
      [] -> [[]]
      paths -> paths
    end
    |> Enum.map(&(objects ++ &1))
  end

  defp map() do
    objects =
      Aoc.input_lines(__MODULE__)
      |> Stream.with_index()
      |> Enum.flat_map(&objects(&1))

    %{
      my_pos: Keyword.fetch!(objects, :me),
      walls: objects |> Keyword.get_values(:wall) |> MapSet.new(),
      keys:
        objects
        |> Stream.filter(&match?({{:key, _door}, _}, &1))
        |> Enum.into(%{}, fn {{:key, door}, pos} -> {pos, door} end),
      doors:
        objects
        |> Stream.filter(&match?({{:door, _door}, _}, &1))
        |> Enum.into(%{}, fn {{:door, door}, pos} -> {pos, door} end)
    }
  end

  defp objects({line, y}) do
    line
    |> to_charlist()
    |> Stream.with_index()
    |> Stream.map(fn {char, x} -> {type(char), {x, y}} end)
  end

  defp type(char) when char in ?a..?z, do: {:key, char + ?A - ?a}
  defp type(char) when char in ?A..?Z, do: {:door, char}
  defp type(?#), do: :wall
  defp type(?.), do: :path
  defp type(?@), do: :me
end
