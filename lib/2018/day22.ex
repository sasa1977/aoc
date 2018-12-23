defmodule Aoc201822 do
  def run() do
    depth = 3066
    target = {13, 726}

    IO.puts(part1(depth, target))
    IO.puts(part2(depth, target))
  end

  defp part1(depth, target) do
    expand_to_pos(new_cave(depth, target), target).regions
    |> Stream.map(fn {_pos, region} -> risk(region) end)
    |> Enum.sum()
  end

  defp part2(depth, target) do
    initial_search_state(depth, target)
    |> Stream.iterate(&search_further/1)
    |> Stream.take_while(&(not MapSet.member?(&1.positions, {target, :torch})))
    |> Enum.count()
  end

  defp initial_search_state(depth, target) do
    process_pending(%{
      cave: new_cave(depth, target),
      positions: MapSet.new(),
      visited: MapSet.new(),
      pending: %{0 => [{{0, 0}, :torch}]},
      time: 0
    })
  end

  defp search_further(search_state) do
    search_state
    |> expand_current_positions()
    |> bump_time()
    |> process_pending()
  end

  defp bump_time(search_state), do: update_in(search_state.time, &(&1 + 1))

  defp process_pending(search_state) do
    Enum.reduce(
      Map.get(search_state.pending, search_state.time, []),
      update_in(search_state.pending, &Map.delete(&1, search_state.time)),
      fn pos, search_state ->
        positions = MapSet.put(search_state.positions, pos)
        visited = MapSet.put(search_state.visited, pos)
        %{search_state | positions: positions, visited: visited}
      end
    )
  end

  defp expand_current_positions(search_state),
    do: Enum.reduce(search_state.positions, search_state, &expand_position(&2, &1))

  defp expand_position(search_state, {{x, y}, tool} = pos) do
    positions = Enum.filter([{x, y - 1}, {x, y + 1}, {x - 1, y}, {x + 1, y}], fn {x, y} -> x >= 0 and y >= 0 end)
    cave = Enum.reduce(positions, search_state.cave, &expand_to_pos(&2, &1))

    pending =
      positions
      |> Enum.flat_map(&next_positions(pos, &1, cave))
      |> Enum.reject(&MapSet.member?(search_state.visited, &1))
      |> Enum.map(&{transition_time(&1, tool, search_state.time), &1})
      |> Enum.reduce(
        search_state.pending,
        fn {time, pos}, pending ->
          Map.update(pending, time, MapSet.new([pos]), &MapSet.put(&1, pos))
        end
      )

    positions = MapSet.delete(search_state.positions, pos)
    %{search_state | cave: cave, positions: positions, pending: pending}
  end

  defp transition_time({_pos, tool}, tool, time), do: time + 1
  defp transition_time({_pos, _}, _, time), do: time + 8

  defp next_positions({current_pos, _}, desired_pos, cave) do
    MapSet.intersection(
      MapSet.new(allowed_tools(cave, desired_pos)),
      MapSet.new(allowed_tools(cave, current_pos))
    )
    |> Enum.map(&{desired_pos, &1})
  end

  defp allowed_tools(cave, to) do
    case at(cave, to).type do
      :rocky -> [:climbing_gear, :torch]
      :wet -> [:climbing_gear, :neither]
      :narrow -> [:torch, :neither]
    end
  end

  defp risk(%{type: :rocky}), do: 0
  defp risk(%{type: :wet}), do: 1
  defp risk(%{type: :narrow}), do: 2

  defp new_cave(depth, target) do
    cave = %{depth: depth, target: target, regions: %{}, right: 0, bottom: 0}
    explore_location(cave, {0, 0})
  end

  defp expand_to_pos(cave, {target_x, target_y}) do
    cave
    |> Stream.iterate(&expand_right/1)
    |> Enum.find(&(&1.right >= target_x))
    |> Stream.iterate(&expand_down/1)
    |> Enum.find(&(&1.bottom >= target_y))
  end

  defp expand_right(cave),
    do: %{Enum.reduce(0..cave.bottom, cave, &explore_location(&2, {cave.right + 1, &1})) | right: cave.right + 1}

  defp expand_down(cave),
    do: %{Enum.reduce(0..cave.right, cave, &explore_location(&2, {&1, cave.bottom + 1})) | bottom: cave.bottom + 1}

  defp explore_location(cave, pos) do
    geologic_index = geologic_index(pos, cave)
    erosion_level = rem(geologic_index + cave.depth, 20183)
    type = Map.fetch!(%{0 => :rocky, 1 => :wet, 2 => :narrow}, rem(erosion_level, 3))
    region = %{geologic_index: geologic_index, erosion_level: erosion_level, type: type}
    %{cave | regions: Map.put(cave.regions, pos, region)}
  end

  defp geologic_index({0, 0}, _cave), do: 0
  defp geologic_index({x, y}, %{target: {x, y}}), do: 0
  defp geologic_index({x, 0}, _cave), do: x * 16807
  defp geologic_index({0, y}, _cave), do: y * 48271
  defp geologic_index({x, y}, cave), do: at(cave, {x - 1, y}).erosion_level * at(cave, {x, y - 1}).erosion_level

  defp at(cave, pos), do: Map.fetch!(cave.regions, pos)
end
