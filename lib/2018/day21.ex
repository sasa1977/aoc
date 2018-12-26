defmodule Aoc201821 do
  alias Aoc2018.Device

  def run() do
    IO.puts(part1())
    IO.puts(part2())
  end

  defp part1(), do: Enum.at(terminating_inputs(), 0)
  defp part2(), do: Enum.at(terminating_inputs(), -1)

  defp terminating_inputs() do
    Aoc.input_file(2018, 21)
    |> Device.from_file()
    |> Device.all_states(optimize: %{18 => &optimized_inner_loop/1})
    # according to the input program, termination happens in instruction 28, if input (r0) == r1
    |> Stream.filter(&(&1.ip == 28))
    |> Stream.transform(MapSet.new(), fn device, seen_states ->
      # if we're on the same instruction with the same registers, the device will cycle, so we stop here
      if MapSet.member?(seen_states, device.registers),
        do: {:halt, seen_states},
        else: {[device], MapSet.put(seen_states, device.registers)}
    end)
    |> Stream.map(&Device.register(&1, 1))
    |> Stream.uniq()
  end

  defp optimized_inner_loop(%{ip: 18} = device) do
    # optimized version of the inner loop, see comments in the input file for details
    d = Device.register(device, 3)
    f = Device.register(device, 5)
    d = if d > f, do: d, else: div(f, 256)

    device
    |> Device.put_register(2, 1)
    |> Device.put_register(3, d)
    |> Device.set_next_instruction(26)
  end
end
