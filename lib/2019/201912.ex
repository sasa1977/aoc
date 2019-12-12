defmodule Aoc201912 do
  def run do
    IO.inspect(part1())
    IO.inspect(part2())
  end

  defp part1() do
    universe_states()
    |> Enum.at(1000)
    |> total_energy()
  end

  defp part2() do
    ~w/x y z/a
    |> Enum.map(&cycle_length/1)
    |> lcm()
  end

  defp cycle_length(axis) do
    Stream.transform(
      universe_states(),
      MapSet.new(),
      fn universe, encountered ->
        constellation = Enum.map(moons(), &{universe[&1].position[axis], universe[&1].velocity[axis]})

        if MapSet.member?(encountered, constellation),
          do: {:halt, encountered},
          else: {[universe], MapSet.put(encountered, constellation)}
      end
    )
    |> Enum.count()
  end

  defp lcm([a, b]), do: div(a * b, Integer.gcd(a, b))
  defp lcm([a | [_, _ | _] = rest]), do: lcm([a, lcm(rest)])

  defp universe_states() do
    Stream.iterate(
      universe(),
      &(&1 |> update_velocities() |> update_positions())
    )
  end

  defp total_energy(universe) do
    moons()
    |> Stream.map(&moon_energy(universe, &1))
    |> Enum.sum()
  end

  defp moon_energy(universe, moon) do
    {positions, velocities} =
      ~w/x y z/a
      |> Stream.map(&{abs(universe[moon].position[&1]), abs(universe[moon].velocity[&1])})
      |> Enum.unzip()

    Enum.sum(positions) * Enum.sum(velocities)
  end

  defp update_positions(universe) do
    for moon <- moons(),
        axis <- ~w/x y z/a,
        reduce: universe do
      universe -> update_in(universe[moon].position[axis], &(&1 + universe[moon].velocity[axis]))
    end
  end

  defp update_velocities(universe) do
    for {moon1, moon2} <- moon_pairs(),
        axis <- ~w/x y z/a,
        delta = sign(universe[moon2].position[axis] - universe[moon1].position[axis]),
        reduce: universe do
      universe ->
        universe
        |> update_in([moon1, :velocity, axis], &(&1 + delta))
        |> update_in([moon2, :velocity, axis], &(&1 - delta))
    end
  end

  defp sign(0), do: 0
  defp sign(num) when num > 0, do: 1
  defp sign(_num), do: -1

  defp moon_pairs(),
    do: for(el1 <- moons(), el2 <- moons(), el1 < el2, do: {el1, el2})

  defp moons(), do: ~w/io europa ganymede callisto/a

  defp universe() do
    moons()
    |> Stream.zip(positions())
    |> Enum.into(%{}, fn {name, position} -> {name, %{position: position, velocity: %{x: 0, y: 0, z: 0}}} end)
  end

  defp positions(), do: Stream.map(Aoc.input_lines(__MODULE__), &parse_position/1)

  defp parse_position(line) do
    Enum.into(
      Regex.named_captures(
        ~r/^<
          x=(?<x>-?\d+),\s*
          y=(?<y>-?\d+),\s*
          z=(?<z>-?\d+)
        >$/x,
        line
      ),
      %{},
      fn {key, value} -> {String.to_atom(key), String.to_integer(value)} end
    )
  end
end
