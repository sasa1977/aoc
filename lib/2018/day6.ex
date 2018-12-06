defmodule Aoc201806 do
  def run() do
    part1(coordinates()) |> IO.inspect()
    part2(coordinates()) |> IO.inspect()
  end

  defp part1(coordinates) do
    reduce_known_universe(
      coordinates,
      %{},
      fn position, coordinate_id, distance, state ->
        new_value = %{id: coordinate_id, distance: distance, tie: false}

        Map.update(state, position, new_value, fn
          %{distance: ^distance} = value -> %{value | tie: true}
          %{distance: smaller_distance} = value when smaller_distance < distance -> value
          _larger_distance -> new_value
        end)
      end
    )
    |> Stream.filter(&match?({_position, %{tie: false}}, &1))
    |> Stream.map(fn {_position, value} -> value.id end)
    |> Aoc.EnumHelper.frequency_map()
    |> Map.values()
    |> Enum.max()
  end

  defp part2(coordinates) do
    reduce_known_universe(
      coordinates,
      %{},
      fn position, _coordinate_id, distance, state -> Map.update(state, position, distance, &(&1 + distance)) end
    )
    |> Map.values()
    |> Stream.filter(&(&1 < 10_000))
    |> Enum.count()
  end

  defp reduce_known_universe(coordinates, state, fun) do
    x_range = Enum.min_by(coordinates, & &1.x).x..Enum.max_by(coordinates, & &1.x).x
    y_range = Enum.min_by(coordinates, & &1.y).y..Enum.max_by(coordinates, & &1.y).y

    Enum.reduce(x_range.first..x_range.last, state, fn x, state ->
      Enum.reduce(y_range.first..y_range.last, state, fn y, state ->
        position = %{x: x, y: y}

        Enum.reduce(coordinates, state, fn coordinate, state ->
          distance = manhattan_distance(position, coordinate)
          fun.(position, coordinate.id, distance, state)
        end)
      end)
    end)
  end

  defp manhattan_distance(a, b), do: abs(a.x - b.x) + abs(a.y - b.y)

  defp coordinates() do
    Aoc.input_lines(2018, 6)
    |> Stream.map(&parse_coordinate/1)
    |> Stream.with_index()
    |> Enum.map(fn {coordinate, offset} -> Map.put(coordinate, :id, "#{[?A + offset]}") end)
  end

  defp parse_coordinate(coordinate) do
    [x, y] = coordinate |> String.split(", ") |> Enum.map(&String.to_integer/1)
    %{x: x, y: y}
  end
end
