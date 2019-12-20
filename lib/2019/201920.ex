defmodule Aoc201920 do
  def run do
    Aoc.output(&part1/0)
    Aoc.output(&part2/0)
  end

  defp part1(), do: shortest_path(map(), &simple_transport/3)
  defp part2(), do: shortest_path(map(), &recursive_transport/3)

  defp simple_transport(map, portal, position),
    do: if(not is_nil(portal.to), do: %{position | pos: transport_destination(map, portal)})

  defp recursive_transport(map, portal, position) do
    if not is_nil(portal.to) and (not portal.outer? or position.level > 0) do
      new_pos = transport_destination(map, portal)
      new_level = position.level + if(portal.outer?, do: -1, else: 1)
      %{position | pos: new_pos, level: new_level}
    end
  end

  defp transport_destination(map, portal),
    do: portal.to |> neighbours() |> Enum.find(&(Map.get(map, &1) == :tile))

  defp shortest_path({map, start}, transporter) do
    initial_search_step(map, start, transporter)
    |> Stream.iterate(&next_search_step/1)
    |> Stream.map(& &1.objects)
    |> Enum.find_index(&goal_reached?/1)
  end

  defp initial_search_step(map, start, transporter),
    do: %{map: map, objects: objects(map, [start]), transporter: transporter, visited: MapSet.new()}

  defp goal_reached?(objects),
    do: Enum.any?(objects, &match?({%{level: 0}, {:portal, %{name: "ZZ"}}}, &1))

  defp next_search_step(state) do
    next_positions =
      state.objects
      |> Stream.map(fn
        {pos, :tile} -> pos
        {position, {:portal, portal}} -> state.transporter.(state.map, portal, position)
      end)
      |> Stream.reject(&is_nil/1)
      |> Stream.reject(&MapSet.member?(state.visited, &1))
      |> MapSet.new()

    state
    |> Map.update!(:visited, &MapSet.union(&1, MapSet.new(Map.keys(state.objects))))
    |> Map.put(:objects, objects(state.map, next_positions))
  end

  defp objects(map, positions) do
    positions
    |> Enum.flat_map(fn position -> Enum.map(neighbours(position.pos), &%{position | pos: &1}) end)
    |> Enum.map(&{&1, Map.get(map, &1.pos)})
    |> Enum.reject(&match?({_position, nil}, &1))
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

    {map, %{pos: start, level: 0}}
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
