defmodule Aoc201825 do
  def run(), do: IO.inspect(part1())

  defp part1(), do: Enum.count(groups())

  defp groups() do
    points()
    |> Stream.unfold(&pop_group/1)
    |> Stream.take_while(&(not is_nil(&1)))
  end

  defp pop_group([]), do: nil
  defp pop_group([point | rest]), do: pop_group_of(point, rest)

  defp pop_group_of(point, points), do: pop_group_of(point, [point], points)

  defp pop_group_of(point, group_acc, points) do
    {neighbours, rest} = Enum.split_with(points, &(manhattan_distance(&1, point) <= 3))

    Enum.reduce(
      neighbours,
      {group_acc, rest},
      fn neighbour, {group_acc, rest} -> pop_group_of(neighbour, [neighbour | group_acc], rest) end
    )
  end

  defp manhattan_distance({x1, y1, z1, t1}, {x2, y2, z2, t2}),
    do: abs(x1 - x2) + abs(y1 - y2) + abs(z1 - z2) + abs(t1 - t2)

  defp points(), do: Aoc.input_lines(2018, 25) |> Stream.map(&String.split(&1, ",")) |> Enum.map(&parse_point/1)
  defp parse_point(coordinates), do: coordinates |> Enum.map(&String.to_integer/1) |> List.to_tuple()
end
