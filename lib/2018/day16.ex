defmodule Aoc201816 do
  def run() do
    IO.puts(part1(read_input()))
    IO.puts(part2(read_input()))
  end

  defp part1(input) do
    input.trace
    |> Stream.map(&possible_instructions/1)
    |> Stream.filter(fn {_opcode, possible_instructions} -> length(possible_instructions) >= 3 end)
    |> Enum.count()
  end

  defp part2(input), do: input.program |> exec_program(reverse_engineer_instructions(input.trace)) |> get_reg(0)

  defp read_input() do
    [trace, program] = Aoc.input_file(2018, 16) |> File.read!() |> String.split(~r/\n\n\n+/)
    %{trace: parse_trace(trace), program: parse_program(program)}
  end

  defp parse_trace(trace) do
    trace
    |> String.split("\n")
    |> Stream.reject(&(&1 == ""))
    |> Stream.chunk_every(3)
    |> Enum.map(&parse_trace_entry/1)
  end

  defp parse_trace_entry([prev, input, next]) do
    %{"list" => prev} = Regex.named_captures(~r/Before:\s+\[(?<list>.+)\]/, prev)
    prev = prev |> String.split(~r/,\s*/) |> Enum.map(&String.to_integer/1)

    input = input |> String.split(~r/\s+/) |> Enum.map(&String.to_integer/1)

    %{"list" => next} = Regex.named_captures(~r/After:\s+\[(?<list>.+)\]/, next)
    next = next |> String.split(~r/,\s*/) |> Enum.map(&String.to_integer/1)

    %{prev: prev, input: input, next: next}
  end

  defp parse_program(instructions),
    do: instructions |> String.split("\n") |> Stream.reject(&(&1 == "")) |> Enum.map(&parse_instruction/1)

  defp parse_instruction(instruction), do: instruction |> String.split() |> Enum.map(&String.to_integer/1)

  defp possible_instructions(trace) do
    [opcode, a, b, c] = trace.input

    possible_instructions =
      Enum.filter(
        all_instructions(),
        &(trace.prev |> new_machine() |> exec(&1, a, b, c) |> registers() == trace.next)
      )

    {opcode, possible_instructions}
  end

  defp reverse_engineer_instructions(trace) do
    trace
    |> Stream.map(&possible_instructions/1)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.map(fn {opcode, all_instructions} -> {opcode, all_instructions |> Stream.concat() |> Enum.uniq()} end)
    |> opcodes(%{})
    |> Stream.map(fn {instruction, opcode} -> {opcode, instruction} end)
    |> Map.new()
  end

  defp opcodes(_traces = [], opcodes), do: opcodes

  defp opcodes([{current_opcode, instructions} | remaining_traces], opcodes) do
    instructions
    |> Stream.reject(&Map.has_key?(opcodes, &1))
    |> Stream.map(&opcodes(remaining_traces, Map.put(opcodes, &1, current_opcode)))
    |> Enum.find(&(not is_nil(&1)))
  end

  defp exec_program(program, instructions) do
    Enum.reduce(
      program,
      new_machine(),
      fn [op, a, b, c], machine -> exec(machine, Map.fetch!(instructions, op), a, b, c) end
    )
  end

  defp new_machine(register_values \\ [0, 0, 0, 0]),
    do: register_values |> Stream.with_index() |> Stream.map(fn {value, pos} -> {pos, value} end) |> Map.new()

  defp registers(machine),
    do: machine |> Enum.sort_by(fn {pos, _value} -> pos end) |> Enum.map(fn {_pos, value} -> value end)

  defp get_reg(machine, pos), do: Map.fetch!(machine, pos)
  defp put_reg(machine, pos, value), do: Map.put(machine, pos, value)

  defp all_instructions(), do: Map.keys(instructions())

  defp exec(machine, instruction, a, b, c), do: Map.fetch!(instructions(), instruction).(machine, a, b, c)

  defp instructions() do
    %{
      addr: &put_reg(&1, &4, get_reg(&1, &2) + get_reg(&1, &3)),
      addi: &put_reg(&1, &4, get_reg(&1, &2) + &3),
      mulr: &put_reg(&1, &4, get_reg(&1, &2) * get_reg(&1, &3)),
      muli: &put_reg(&1, &4, get_reg(&1, &2) * &3),
      banr: &put_reg(&1, &4, :erlang.band(get_reg(&1, &2), get_reg(&1, &3))),
      bani: &put_reg(&1, &4, :erlang.band(get_reg(&1, &2), &3)),
      borr: &put_reg(&1, &4, :erlang.bor(get_reg(&1, &2), get_reg(&1, &3))),
      bori: &put_reg(&1, &4, :erlang.bor(get_reg(&1, &2), &3)),
      gtir: &put_reg(&1, &4, if(&2 > get_reg(&1, &3), do: 1, else: 0)),
      gtri: &put_reg(&1, &4, if(get_reg(&1, &2) > &3, do: 1, else: 0)),
      gtrr: &put_reg(&1, &4, if(get_reg(&1, &2) > get_reg(&1, &3), do: 1, else: 0)),
      eqir: &put_reg(&1, &4, if(&2 == get_reg(&1, &3), do: 1, else: 0)),
      eqri: &put_reg(&1, &4, if(get_reg(&1, &2) == &3, do: 1, else: 0)),
      eqrr: &put_reg(&1, &4, if(get_reg(&1, &2) == get_reg(&1, &3), do: 1, else: 0)),
      setr: fn machine, reg_a, _b, reg_c -> put_reg(machine, reg_c, get_reg(machine, reg_a)) end,
      seti: fn machine, val, _b, reg_c -> put_reg(machine, reg_c, val) end
    }
  end
end
