defmodule Aoc201910 do
  def run() do
    IO.inspect(part1())
    IO.inspect(part2())
  end

  defp part1() do
    universe = universe()

    universe
    |> lines_of_sight(monitoring_station(universe))
    |> Enum.count()
  end

  defp part2() do
    {x, y} = Enum.at(vaporized_asteroids(universe()), 199)
    x * 100 + y
  end

  defp vaporized_asteroids(universe) do
    station = monitoring_station(universe)
    Stream.resource(fn -> universe end, &vaporize_round(&1, station), & &1)
  end

  defp vaporize_round(universe, station) do
    {vectors, lines_of_sight} =
      lines_of_sight(universe, station)
      |> Enum.sort_by(fn {vector, _asteroids} -> vector |> rotate_by90_ccr() |> angle() end, &>=/2)
      |> Stream.map(fn {vector, asteroids} ->
        {asteroid, remaining_asteroids} = pop_first(asteroids)
        {asteroid, {vector, remaining_asteroids}}
      end)
      |> Enum.unzip()

    lines_of_sight = Enum.reject(lines_of_sight, fn {_vector, asteroids} -> :gb_trees.size(asteroids) == 0 end)

    {vectors, Map.put(universe, station, lines_of_sight)}
  end

  # we're inverting y, since in Euclidean plane y has the opposite orientation
  defp angle({dx, dy}), do: :math.atan2(-dy, dx)

  defp rotate_by90_ccr({dx, dy}), do: {dy, -dx}

  defp pop_first(tree) do
    {key, value} = :gb_trees.smallest(tree)
    {value, :gb_trees.delete(key, tree)}
  end

  defp monitoring_station(universe) do
    universe
    |> asteroids()
    |> Enum.max_by(&lines_of_sight(universe, &1))
  end

  defp asteroids(universe), do: Map.keys(universe)
  defp lines_of_sight(universe, asteroid), do: Map.fetch!(universe, asteroid)

  defp universe(), do: Enum.reduce(asteroids(), %{}, &add_asteroid(&2, &1))

  defp add_asteroid(universe, asteroid) do
    Enum.reduce(
      Map.keys(universe),
      Map.put(universe, asteroid, %{}),
      fn asteroid2, universe ->
        universe
        |> record_line_of_sight(asteroid, asteroid2)
        |> record_line_of_sight(asteroid2, asteroid)
      end
    )
  end

  defp record_line_of_sight(universe, asteroid_from, asteroid_to) do
    {dx, dy} = vector(asteroid_from, asteroid_to)
    distance = Integer.gcd(dx, dy)
    normalized_vector = {div(dx, distance), div(dy, distance)}

    lines_of_sight =
      Map.update(
        Map.fetch!(universe, asteroid_from),
        normalized_vector,
        :gb_trees.from_orddict([{distance, asteroid_to}]),
        &:gb_trees.enter(distance, asteroid_to, &1)
      )

    Map.put(universe, asteroid_from, lines_of_sight)
  end

  defp asteroids() do
    Aoc.input_lines(__MODULE__)
    |> Stream.with_index()
    |> Stream.flat_map(fn {cols, y} ->
      cols
      |> to_charlist()
      |> Stream.with_index()
      |> Stream.map(&asteroid(&1, y))
    end)
    |> Stream.reject(&is_nil/1)
  end

  defp asteroid({?#, x}, y), do: {x, y}
  defp asteroid({?., _}, _), do: nil

  defp vector({x1, y1}, {x2, y2}), do: {x2 - x1, y2 - y1}
end
