defmodule Aoc201820 do
  alias Aoc201820.Parser

  def run() do
    IO.puts(part1())
    IO.puts(part2())
  end

  defp part1(), do: rooms() |> Stream.map(& &1.distance) |> Enum.max()
  defp part2(), do: rooms() |> Stream.filter(&(&1.distance >= 1000)) |> Enum.count()

  def rooms() do
    Aoc.input_file(2018, 20)
    |> File.read!()
    |> String.trim()
    |> Parser.instructions()
    |> collect_neighbours()
    |> collect_rooms()
  end

  defp collect_rooms(neighbours) do
    %{distance: 0, next_rooms: MapSet.new([{0, 0}]), neighbours: neighbours}
    |> Stream.unfold(&{current_rooms(&1), next_rooms(&1)})
    |> Stream.take_while(&(not Enum.empty?(&1)))
    |> Stream.concat()
  end

  defp current_rooms(collect_rooms_state),
    do: Enum.map(collect_rooms_state.next_rooms, &%{distance: collect_rooms_state.distance, at: &1})

  defp next_rooms(collect_rooms_state) do
    Enum.reduce(
      collect_rooms_state.next_rooms,
      %{collect_rooms_state | next_rooms: MapSet.new(), distance: collect_rooms_state.distance + 1},
      &move_to_neighbours/2
    )
  end

  defp move_to_neighbours(room, collect_rooms_state) do
    next_rooms =
      collect_rooms_state.neighbours
      |> Map.fetch!(room)
      |> Enum.filter(&Map.has_key?(collect_rooms_state.neighbours, &1))
      |> MapSet.new()
      |> MapSet.union(collect_rooms_state.next_rooms)

    neighbours = Map.delete(collect_rooms_state.neighbours, room)

    %{collect_rooms_state | neighbours: neighbours, next_rooms: next_rooms}
  end

  defp collect_neighbours(instructions),
    do: collect_neighbours(instructions, %{positions: MapSet.new([{0, 0}]), neighbours: %{}}).neighbours

  defp collect_neighbours(instructions, collect_neighbours_state),
    do: Enum.reduce(instructions, collect_neighbours_state, &process_instruction/2)

  defp process_instruction({:move, direction}, collect_neighbours_state) do
    Enum.reduce(
      collect_neighbours_state.positions,
      %{collect_neighbours_state | positions: MapSet.new()},
      &record_move(&2, &1, move(&1, direction))
    )
  end

  defp process_instruction({:switch, type, branches}, state_before_switch) do
    Enum.reduce(
      branches,
      if(type == :mandatory, do: %{state_before_switch | positions: MapSet.new()}, else: state_before_switch),
      fn branch_instructions, state_before_branch ->
        branch_instructions
        |> collect_neighbours(%{state_before_branch | positions: state_before_switch.positions})
        |> update_in([:positions], &MapSet.union(&1, state_before_branch.positions))
      end
    )
  end

  defp record_move(collect_neighbours_state, pos1, pos2) do
    positions = MapSet.put(collect_neighbours_state.positions, pos2)

    neighbours =
      collect_neighbours_state.neighbours
      |> Map.update(pos1, MapSet.new([pos2]), &MapSet.put(&1, pos2))
      |> Map.update(pos2, MapSet.new([pos1]), &MapSet.put(&1, pos1))

    %{collect_neighbours_state | positions: positions, neighbours: neighbours}
  end

  defp move({x, y}, :north), do: {x, y + 1}
  defp move({x, y}, :south), do: {x, y - 1}
  defp move({x, y}, :east), do: {x + 1, y}
  defp move({x, y}, :west), do: {x - 1, y}

  defmodule Parser do
    def instructions("^" <> rest) do
      {instructions, "$"} = parse_instructions(rest)
      instructions
    end

    defp parse_instructions(input) do
      case next_element(input) do
        nil ->
          {[], input}

        {element, rest} ->
          {remaining_elements, rest} = parse_instructions(rest)
          {[element | remaining_elements], rest}
      end
    end

    defp next_element("N" <> rest), do: {{:move, :north}, rest}
    defp next_element("S" <> rest), do: {{:move, :south}, rest}
    defp next_element("E" <> rest), do: {{:move, :east}, rest}
    defp next_element("W" <> rest), do: {{:move, :west}, rest}
    defp next_element("(" <> rest), do: parse_switch(rest)
    defp next_element(_unknown), do: nil

    defp parse_switch(input) do
      {branches, rest} = parse_branches(input)

      {switch_type, rest} =
        case rest do
          ")" <> rest -> {:mandatory, rest}
          "|)" <> rest -> {:optional, rest}
        end

      {{:switch, switch_type, branches}, rest}
    end

    defp parse_branches(input) do
      case parse_instructions(input) do
        {branch, ")" <> _ = rest} ->
          {[branch], rest}

        {branch, "|)" <> _ = rest} ->
          {[branch], rest}

        {branch, "|" <> rest} ->
          {remaining_branches, rest} = parse_branches(rest)
          {[branch | remaining_branches], rest}
      end
    end
  end
end
