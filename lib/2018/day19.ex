defmodule Aoc201819 do
  alias Aoc2018.Device

  def run() do
    IO.puts(part1())
    IO.puts(part2())
  end

  defp part1(), do: all_device_states() |> Enum.at(-1) |> Device.register(0)

  defp part2() do
    all_device_states(input: 1, optimize: %{1 => &optimize_part_2/1})
    |> Enum.at(-1)
    |> Device.register(0)
  end

  defp all_device_states(opts \\ []) do
    Aoc.input_file(2018, 19)
    |> Device.from_file()
    |> Device.put_register(0, Keyword.get(opts, :input, 0))
    |> Device.all_states(Keyword.take(opts, [:optimize]))
  end

  defp optimize_part_2(device) do
    # This is obtained by reverse engineering the input program. Therefore, this code won't work for other inputs.
    # After reverse engineering the program  (you can find pseudoassembly equivalent in the input file), I've
    # established that it does the following:
    # - If the first registry is set to 1, the program first computes the input number and puts it to registry E (r4).
    # - The program then starts looping from the instruction 1.
    # - The final result in the registry A (r0) will contain the sum of divisors of the input number.

    device
    |> Device.put_register(0, Device.register(device, 4) |> divisors() |> Enum.sum())
    |> Device.set_next_instruction(100_000)
  end

  defp divisors(num) do
    Stream.iterate(1, &(&1 + 1))
    |> Stream.take_while(&(&1 * &1 <= num))
    |> Stream.filter(&(rem(num, &1) == 0))
    |> Stream.flat_map(&[&1, div(num, &1)])
    |> Stream.uniq()
  end
end
