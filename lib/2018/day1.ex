defmodule Aoc201801 do
  def run() do
    frequency_changes =
      Aoc.input_file(2018, 1)
      |> File.stream!()
      |> Stream.map(&String.trim/1)
      |> Stream.map(&String.to_integer/1)

    part1(frequency_changes) |> IO.inspect()
    part2(frequency_changes) |> IO.inspect()
  end

  defp part1(frequency_changes) do
    frequency_changes
    |> frequencies()
    |> Enum.reduce(nil, fn frequency, _previous -> frequency end)
  end

  defp part2(frequency_changes) do
    frequency_changes
    |> Stream.cycle()
    |> frequencies()
    |> Stream.transform(
      MapSet.new(),
      fn frequency, frequencies ->
        if MapSet.member?(frequencies, frequency),
          do: {[frequency], frequencies},
          else: {[], MapSet.put(frequencies, frequency)}
      end
    )
    |> Enum.take(1)
    |> hd()
  end

  defp frequencies(frequency_changes) do
    Stream.scan(
      frequency_changes,
      0,
      fn frequency_change, frequency -> frequency + frequency_change end
    )
  end
end
