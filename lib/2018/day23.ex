defmodule Aoc201823 do
  def run() do
    IO.puts(part1())
    IO.puts(part2())
  end

  defp part1() do
    bots = bots()
    strongest_bot = Enum.max_by(bots, & &1.radius)
    bots |> Stream.filter(&in_range?(&1, strongest_bot)) |> Enum.count()
  end

  defp part2() do
    bots()
    |> positions_ordered_by_bots_range()
    |> Stream.chunk_by(& &1.bots)
    |> Enum.at(0)
    |> Stream.map(&manhattan_distance(&1, origin()))
    |> Enum.min()
  end

  defp origin(), do: %{x: 0, y: 0, z: 0}

  defp positions_ordered_by_bots_range(bots) do
    # Returns a lazy collection of positions, ordered by the number of bots they are in range of.
    # This is computed using the following algorithm:
    # 1. Start with the single element list containing the cube which encompasses all the nanobots.
    # 2. Find the cube in the list which intersects with most of the nanobots.
    # 3. Split that cube into 8 smaller cubes (dividing each dimension by 2) and return those cubes to the queue.
    #    If the cubes are of size 1, they are not returned to the queue. Cubes which intersect with zero bots are also
    #    not returned to the queue.
    # 4. Loop from step 2, stop when there are no more cubes in the queue.
    Stream.unfold(
      [surrounding_cube(bots)],
      fn cubes ->
        with {best_cube, cubes} <- pop_best_cube(cubes) do
          if size(best_cube) > 1 do
            new_cubes = best_cube |> split_cube(bots) |> Enum.filter(&(&1.bots > 0))
            {best_cube, new_cubes ++ cubes}
          else
            {best_cube, cubes}
          end
        end
      end
    )
    # take only cubes of size 1 (which are effectively positions)
    |> Stream.filter(&(size(&1) == 1))
    # convert cube to position, including bot count
    |> Stream.map(&%{x: &1.x.first, y: &1.y.first, z: &1.z.first, bots: &1.bots})
  end

  defp size(cube),
    do: (cube.x.last - cube.x.first + 1) * (cube.y.last - cube.y.first + 1) * (cube.z.last - cube.z.first + 1)

  defp surrounding_cube(bots) do
    [:x, :y, :z]
    |> Enum.map(fn dimension ->
      {from, to} = bots |> Stream.map(&Map.fetch!(&1.center, dimension)) |> Enum.min_max()
      {dimension, from..to}
    end)
    |> Map.new()
    |> count_cube_bots(bots)
  end

  defp split_cube(cube, bots) do
    for x_range <- split_range(cube.x),
        y_range <- split_range(cube.y),
        z_range <- split_range(cube.z) do
      count_cube_bots(%{x: x_range, y: y_range, z: z_range}, bots)
    end
  end

  defp split_range(%Range{first: last, last: last} = range), do: [range]

  defp split_range(range) do
    split = div(range.last - range.first, 2)

    [
      range.first..(range.first + split),
      (range.first + split + 1)..range.last
    ]
  end

  defp count_cube_bots(cube, bots), do: Map.put(cube, :bots, Enum.count(bots, &intersect?(cube, &1)))

  defp pop_best_cube(queue) do
    Enum.reduce(
      queue,
      nil,
      fn
        cube, nil ->
          {cube, []}

        cube, {best, remaining} ->
          if cube.bots > best.bots, do: {cube, [best | remaining]}, else: {best, [cube | remaining]}
      end
    )
  end

  defp intersect?(cube, bot), do: manhattan_distance(closest_pos(cube, bot.center), bot.center) <= bot.radius

  defp closest_pos(cube, target_pos) do
    [:x, :y, :z]
    |> Enum.map(&{&1, Map.fetch!(target_pos, &1), cube[&1].first, cube[&1].last})
    |> Enum.map(fn {dimension, target_pos, from, to} ->
      closest =
        cond do
          target_pos < from -> from
          target_pos > to -> to
          true -> target_pos
        end

      {dimension, closest}
    end)
    |> Map.new()
  end

  defp in_range?(bot, of_bot), do: manhattan_distance(bot.center, of_bot.center) <= of_bot.radius

  defp manhattan_distance(pos1, pos2), do: abs(pos1.x - pos2.x) + abs(pos1.y - pos2.y) + abs(pos1.z - pos2.z)

  defp bots(), do: Enum.map(Aoc.input_lines(2018, 23), &parse_bot/1)

  defp parse_bot(bot_def) do
    %{"center" => center, "r" => radius} = Regex.named_captures(~r/pos=<(?<center>.+)>, r=(?<r>.*)/, bot_def)
    [x, y, z] = Enum.map(String.split(center, ","), &String.to_integer/1)

    %{
      radius: String.to_integer(radius),
      center: %{x: x, y: y, z: z}
    }
  end
end
