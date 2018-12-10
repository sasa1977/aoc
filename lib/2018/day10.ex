defmodule Aoc201810 do
  def run do
    IO.puts(part1())
    IO.puts(part2())
  end

  defp part1(), do: points() |> all_states() |> Enum.find(&message_appeared?/1) |> printable_map()
  defp part2(), do: points() |> all_states() |> Stream.take_while(&(not message_appeared?(&1))) |> Enum.count()

  defp points(), do: Enum.map(Aoc.input_lines(2018, 10), &parse_line/1)

  defp parse_line(line) do
    %{"vx" => vx, "vy" => vy, "x" => x, "y" => y} =
      Regex.named_captures(
        ~r/position=<\s*(?<x>\-?\d+),\s*(?<y>\-?\d+)> velocity=<\s*(?<vx>\-?\d+),\s*(?<vy>\-?\d+)>/,
        line
      )

    %{x: String.to_integer(x), y: String.to_integer(y), vx: String.to_integer(vx), vy: String.to_integer(vy)}
  end

  defp all_states(points), do: Stream.iterate(points, &next_state/1)
  defp next_state(points), do: Enum.map(points, &%{&1 | x: &1.x + &1.vx, y: &1.y + &1.vy})

  defp printable_map(points) do
    positions = points |> Stream.map(&Map.take(&1, [:x, :y])) |> MapSet.new()
    {left, right} = positions |> Stream.map(& &1.x) |> Enum.min_max()
    {top, bottom} = positions |> Stream.map(& &1.y) |> Enum.min_max()

    Enum.map(top..bottom, fn y ->
      [
        Enum.map(left..right, fn x -> if MapSet.member?(positions, %{x: x, y: y}), do: ?#, else: ?. end),
        ?\n
      ]
    end)
  end

  defp message_appeared?(points) do
    points
    |> Stream.map(&Map.take(&1, [:x, :y]))
    |> vertical_bounds_of_groups()
    |> Aoc.EnumHelper.all_same?()
  end

  defp vertical_bounds_of_groups(positions) do
    Stream.transform(
      positions,
      MapSet.new(positions),
      fn position, positions ->
        case group_from_position(positions, position) do
          nil -> {[], positions}
          {group, positions} -> {[group], positions}
        end
      end
    )
  end

  defp group_from_position(positions, position) do
    if MapSet.member?(positions, position) do
      Enum.reduce(
        neighbours(position),
        {%{top: position.y, bottom: position.y}, MapSet.delete(positions, position)},
        fn neighbour, {group, positions} ->
          case group_from_position(positions, neighbour) do
            nil -> {group, positions}
            {group_from_neighbour, positions} -> {merge_groups(group, group_from_neighbour), positions}
          end
        end
      )
    else
      nil
    end
  end

  defp neighbours(position),
    do: for(x <- -1..1, y <- -1..1, x != 0 or y != 0, do: %{x: position.x + x, y: position.y + y})

  defp merge_groups(group1, group2), do: %{top: min(group1.top, group2.top), bottom: max(group1.bottom, group2.bottom)}
end
