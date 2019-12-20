defmodule Aoc201920 do
  def run do
    Aoc.output(&part1/0)
    Aoc.output(&part2/0)
  end

  defp part1() do
    {map, start} = map()
    shortest_path(map, [{start, 0}], &simple_transport/3)
  end

  defp part2() do
    {map, start} = map()
    shortest_path(map, [{start, 0}], &recursive_transport/3)
  end

  defp simple_transport(map, portal, 0) do
    if not is_nil(portal.to) do
      new_pos = portal.to |> neighbours() |> Enum.find(&(Map.get(map, &1) == :tile))
      {new_pos, 0}
    end
  end

  defp recursive_transport(map, portal, level) do
    if not portal.outer? or level > 0 do
      with {new_pos, 0} when not is_nil(new_pos) <- simple_transport(map, portal, 0) do
        new_pos = portal.to |> neighbours() |> Enum.find(&(Map.get(map, &1) == :tile))
        new_level = level + if portal.outer?, do: -1, else: 1
        {new_pos, new_level}
      end
    end
  end

  defp shortest_path(map, positions, transporter) do
    Stream.iterate({objects(map, positions), MapSet.new()}, &advance_search(map, transporter, &1))
    |> Stream.map(fn {objects, _visited} -> objects end)
    |> Enum.find_index(fn objects -> Enum.any?(objects, &match?({{_pos, 0}, {:portal, %{name: "ZZ"}}}, &1)) end)
  end

  defp advance_search(map, transporter, {objects, visited}) do
    next_positions =
      objects
      |> Stream.map(fn
        {pos, :tile} -> pos
        {{_pos, level}, {:portal, portal}} -> transporter.(map, portal, level)
      end)
      |> Stream.reject(&is_nil/1)
      |> Stream.reject(&MapSet.member?(visited, &1))
      |> MapSet.new()

    {objects(map, next_positions), MapSet.union(visited, MapSet.new(Map.keys(objects)))}
  end

  defp objects(map, positions) do
    positions
    |> Enum.flat_map(fn {position, level} -> Enum.map(neighbours(position), &{&1, level}) end)
    |> Enum.map(fn {pos, level} -> {{pos, level}, Map.get(map, pos)} end)
    |> Enum.reject(&match?({_pos, nil}, &1))
    |> Map.new()
  end

  defp map() do
    map =
      Aoc.input_lines(__MODULE__, &String.trim_trailing/1)
      |> Enum.with_index()
      |> Stream.flat_map(&elements/1)
      |> Map.new()

    portals = map |> portals() |> Enum.uniq()
    portal_map = Enum.into(portals, %{}, &{{&1.name, not &1.outer?}, &1.at})

    portal_objects =
      Stream.map(
        portals,
        &{&1.at, {:portal, %{name: &1.name, outer?: &1.outer?, to: Map.get(portal_map, {&1.name, &1.outer?})}}}
      )

    map =
      map
      |> Stream.filter(&match?({_pos, ?.}, &1))
      |> Stream.map(fn {pos, ?.} -> {pos, :tile} end)
      |> Stream.concat(portal_objects)
      |> Map.new()

    start =
      Enum.find(portals, &(&1.name == "AA")).at
      |> neighbours()
      |> Enum.find(&(Map.get(map, &1) == :tile))

    {map, start}
  end

  defp portals(map) do
    max_x = Map.keys(map) |> Enum.map(fn {x, _y} -> x end) |> Enum.max()
    max_y = Map.keys(map) |> Enum.map(fn {_x, y} -> y end) |> Enum.max()

    map
    |> Stream.filter(fn {_pos, value} -> value in ?A..?Z end)
    |> Enum.map(fn {pos1, first_letter} ->
      [{second_letter, pos2}] =
        for pos2 <- neighbours(pos1),
            second_letter = Map.get(map, pos2),
            second_letter in ?A..?Z,
            do: {second_letter, pos2}

      [pos] = for pos <- [pos1, pos2], neighbour <- neighbours(pos), Map.get(map, neighbour) == ?., do: pos
      name = if pos1 < pos2, do: <<first_letter, second_letter>>, else: <<second_letter, first_letter>>

      {x, y} = pos
      outer? = x in [1, max_x - 1] or y in [1, max_y - 1]

      %{at: pos, name: name, outer?: outer?}
    end)
  end

  defp neighbours({x, y}), do: [{x + 1, y}, {x - 1, y}, {x, y + 1}, {x, y - 1}]

  defp elements({line, y}) do
    line
    |> to_charlist()
    |> Enum.with_index()
    |> Stream.filter(fn {char, _x} -> char == ?. or char in ?A..?Z end)
    |> Stream.map(fn {char, x} -> {{x, y}, char} end)
  end
end
