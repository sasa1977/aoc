defmodule Aoc201823 do
  def run() do
    IO.inspect(part1())
  end

  defp part1() do
    nanobots = nanobots()
    strongest_nanobot = Enum.max_by(nanobots, & &1.radius)

    nanobots
    |> Stream.filter(&in_range?(&1, strongest_nanobot))
    |> Enum.count()
  end

  defp in_range?(nanobot, of_nanobot), do: manhattan_distance(nanobot.center, of_nanobot.center) <= of_nanobot.radius

  defp manhattan_distance(pos1, pos2), do: abs(pos1.x - pos2.x) + abs(pos1.y - pos2.y) + abs(pos1.z - pos2.z)

  defp nanobots(), do: Enum.map(Aoc.input_lines(2018, 23), &parse_nanobot/1)

  defp parse_nanobot(nanobot_def) do
    %{"center" => center, "r" => radius} = Regex.named_captures(~r/pos=<(?<center>.+)>, r=(?<r>.*)/, nanobot_def)
    [x, y, z] = Enum.map(String.split(center, ","), &String.to_integer/1)

    %{
      radius: String.to_integer(radius),
      center: %{x: x, y: y, z: z}
    }
  end
end
