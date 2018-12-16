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

  Module.register_attribute(__MODULE__, :all_instructions, accumulate: true)

  for {binary_instr, fun} <- [
        {:add, quote(do: &+/2)},
        {:mul, quote(do: &*/2)},
        {:ban, quote(do: &:erlang.band/2)},
        {:bor, quote(do: &:erlang.bor/2)}
      ] do
    @all_instructions :"#{binary_instr}r"
    defp exec(machine, unquote(:"#{binary_instr}r"), reg_a, reg_b, reg_c),
      do: put_reg(machine, reg_c, unquote(fun).(get_reg(machine, reg_a), get_reg(machine, reg_b)))

    @all_instructions :"#{binary_instr}i"
    defp exec(machine, unquote(:"#{binary_instr}i"), reg_a, val_b, reg_c),
      do: put_reg(machine, reg_c, unquote(fun).(get_reg(machine, reg_a), val_b))
  end

  for {comp_instr, fun} <- [{:gt, quote(do: &>/2)}, {:eq, quote(do: &==/2)}] do
    @all_instructions :"#{comp_instr}ir"
    defp exec(machine, unquote(:"#{comp_instr}ir"), val_a, reg_b, reg_c),
      do: put_reg(machine, reg_c, if(unquote(fun).(val_a, get_reg(machine, reg_b)), do: 1, else: 0))

    @all_instructions :"#{comp_instr}ri"
    defp exec(machine, unquote(:"#{comp_instr}ri"), reg_a, val_b, reg_c),
      do: put_reg(machine, reg_c, if(unquote(fun).(get_reg(machine, reg_a), val_b), do: 1, else: 0))

    @all_instructions :"#{comp_instr}rr"
    defp exec(machine, unquote(:"#{comp_instr}rr"), reg_a, reg_b, reg_c),
      do: put_reg(machine, reg_c, if(unquote(fun).(get_reg(machine, reg_a), get_reg(machine, reg_b)), do: 1, else: 0))
  end

  @all_instructions :setr
  defp exec(machine, :setr, reg_a, _b, reg_c), do: put_reg(machine, reg_c, get_reg(machine, reg_a))

  @all_instructions :seti
  defp exec(machine, :seti, val_a, _b, reg_c), do: put_reg(machine, reg_c, val_a)

  defp all_instructions(), do: unquote(Enum.reverse(@all_instructions))
end
