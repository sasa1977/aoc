defmodule Aoc201903 do
  def run do
    IO.inspect(part1())
    IO.inspect(part2())
  end

  defp part1 do
    [wire1, wire2] = wires()

    intersections(wire1, wire2)
    |> Stream.map(&manhattan_distance/1)
    |> Enum.min()
  end

  defp part2() do
    [wire1, wire2] = wires()
    steps = Map.merge(wire_steps(wire1), wire_steps(wire2), fn _key, val1, val2 -> val1 + val2 end)

    intersections(wire1, wire2)
    |> Stream.map(&Map.fetch!(steps, &1))
    |> Enum.min()
  end

  defp wire_steps(wire) do
    wire
    |> Stream.flat_map(fn segment ->
      segment.range
      # dropping the first coordinate because it's either 0,0 or already included as the end of the previous segment
      |> Stream.drop(1)
      |> Stream.map(&%{segment.axis => segment.at, other_axis(segment.axis) => &1})
    end)
    # start with 1 since we dropped 0,0
    |> Stream.with_index(1)
    |> Stream.uniq_by(fn {pos, _steps} -> pos end)
    |> Map.new()
  end

  defp other_axis(:x), do: :y
  defp other_axis(:y), do: :x

  defp intersections(wire1, wire2) do
    wire1
    |> Stream.flat_map(fn segment -> Stream.map(wire2, &intersection(&1, segment)) end)
    |> Stream.reject(&is_nil/1)
    |> Stream.reject(&(&1.x == 0 and &1.y == 0))
  end

  defp manhattan_distance(pos), do: abs(pos.x) + abs(pos.y)

  defp intersection(seg1, seg2) do
    if seg1.axis != seg2.axis and seg1.at in seg2.range and seg2.at in seg1.range,
      do: %{seg1.axis => seg1.at, seg2.axis => seg2.at}
  end

  defp wires(),
    do: Aoc.input_lines(__MODULE__) |> Enum.map(&parse_wire/1) |> Enum.map(&segments/1)

  defp parse_wire(wire_str),
    do: wire_str |> String.split(",") |> Enum.map(&parse_step/1)

  defp parse_step(<<dir_code::utf8, distance::binary>>),
    do: {direction(dir_code), String.to_integer(distance)}

  defp direction(?L), do: :left
  defp direction(?R), do: :right
  defp direction(?U), do: :up
  defp direction(?D), do: :down

  defp segments(wire) do
    Stream.unfold(
      {%{x: 0, y: 0}, wire},
      fn
        {_pos, []} ->
          nil

        {from, [move | rest]} ->
          to = move(from, move)
          {segment(from, to), {to, rest}}
      end
    )
    |> Enum.to_list()
  end

  defp segment(%{y: y} = pos1, %{y: y} = pos2), do: %{range: pos1.x..pos2.x, at: y, axis: :y}
  defp segment(%{x: x} = pos1, %{x: x} = pos2), do: %{range: pos1.y..pos2.y, at: x, axis: :x}

  defp move(pos, {:left, distance}), do: update_in(pos.x, &(&1 - distance))
  defp move(pos, {:right, distance}), do: update_in(pos.x, &(&1 + distance))
  defp move(pos, {:down, distance}), do: update_in(pos.y, &(&1 - distance))
  defp move(pos, {:up, distance}), do: update_in(pos.y, &(&1 + distance))
end
