defmodule Aoc201806 do
  def run() do
    part1(coordinates()) |> IO.inspect()
    part2(coordinates()) |> IO.inspect()
  end

  defp part1(coordinates) do
    closest_map =
      coordinates
      |> all_positions()
      |> Stream.map(&{&1, closest(&1, coordinates)})
      |> Map.new()

    infinite_ids = infinite_ids(coordinates, closest_map)

    closest_map
    |> Map.values()
    |> Stream.reject(&(&1.id == :tie or MapSet.member?(infinite_ids, &1.id)))
    |> Aoc.EnumHelper.frequencies_by(& &1.id)
    |> Map.values()
    |> Enum.max()
  end

  defp infinite_ids(coordinates, closest_map) do
    bounds = bounds(coordinates)

    Stream.concat(
      Stream.flat_map(bounds.top..bounds.bottom, &[%{x: bounds.left, y: &1}, %{x: bounds.right, y: &1}]),
      Stream.flat_map(bounds.left..bounds.right, &[%{x: &1, y: bounds.top}, %{x: &1, y: bounds.bottom}])
    )
    |> Stream.map(&Map.fetch!(closest_map, &1).id)
    |> MapSet.new()
  end

  defp closest(position, coordinates) do
    Enum.reduce(
      coordinates,
      nil,
      fn coordinate, current_closest ->
        new_closest = %{id: coordinate.id, distance: manhattan_distance(coordinate, position)}

        cond do
          is_nil(current_closest) -> new_closest
          new_closest.distance == current_closest.distance -> %{current_closest | id: :tie}
          new_closest.distance < current_closest.distance -> new_closest
          true -> current_closest
        end
      end
    )
  end

  defp all_positions(coordinates) do
    bounds = bounds(coordinates)
    for x <- bounds.left..bounds.right, y <- bounds.top..bounds.bottom, do: %{x: x, y: y}
  end

  defp bounds(coordinates) do
    {%{x: left}, %{x: right}} = Enum.min_max_by(coordinates, & &1.x, & &1.x)
    {%{y: top}, %{y: bottom}} = Enum.min_max_by(coordinates, & &1.y, & &1.y)
    %{left: left, right: right, top: top, bottom: bottom}
  end

  defp part2(coordinates) do
    coordinates
    |> all_positions()
    |> Stream.map(&total_distance(&1, coordinates))
    |> Stream.filter(&(&1 < 10_000))
    |> Enum.count()
  end

  defp total_distance(point, coordinates) do
    coordinates
    |> Stream.map(&manhattan_distance(&1, point))
    |> Enum.sum()
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
