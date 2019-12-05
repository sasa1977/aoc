defmodule Aoc201905 do
  def run do
    IO.inspect(part1())
    IO.inspect(part2())
  end

  defp part1 do
    machine()
    |> push_input(1)
    |> run()
    |> diagnostic_code()
  end

  defp part2 do
    machine()
    |> push_input(5)
    |> run()
    |> diagnostic_code()
  end

  defp diagnostic_code(machine) do
    {_tests, [code]} = Enum.split_while(output(machine), &(&1 == 0))
    code
  end

  defp run(machine) do
    machine
    |> Stream.iterate(&execute_instruction/1)
    |> Stream.take_while(&(not is_nil(&1)))
    |> Enum.at(-1)
  end

  defp execute_instruction(%{ip: ip} = machine) do
    code = mem_read(machine, ip)
    {fun, arity} = fun_info(code)

    with %{ip: ^ip} = machine <- apply(fun, [machine | parameters(machine, code, arity)]),
         do: update_in(machine.ip, &(&1 + arity + 1))
  end

  defp fun_info(code) do
    opcode = rem(code, 100)
    fun = Map.fetch!(instruction_table(), opcode)
    {:arity, arity} = Function.info(fun, :arity)
    {fun, arity - 1}
  end

  defp parameters(machine, code, arity) do
    Stream.unfold(
      {1, div(code, 100)},
      fn {offset, mode_acc} ->
        value = mem_read(machine, machine.ip + offset)
        mode = param_mode(rem(mode_acc, 10))
        {{mode, value}, {offset + 1, div(mode_acc, 10)}}
      end
    )
    |> Enum.take(arity)
  end

  defp param_mode(0), do: :positional
  defp param_mode(1), do: :immediate

  defp instruction_table() do
    %{
      1 => &add/4,
      2 => &mul/4,
      3 => &input/2,
      4 => &output/2,
      5 => &jump_if_true/3,
      6 => &jump_if_false/3,
      7 => &less_than/4,
      8 => &equals/4,
      99 => &halt/1
    }
  end

  defp add(machine, param1, param2, param3),
    do: write(machine, param3, read(machine, param1) + read(machine, param2))

  defp mul(machine, param1, param2, param3),
    do: write(machine, param3, read(machine, param1) * read(machine, param2))

  defp input(machine, param) do
    {{:value, value}, input} = :queue.out(machine.input)
    machine = %{machine | input: input}
    write(machine, param, value)
  end

  defp output(machine, param),
    do: update_in(machine.output, &[&1, read(machine, param)])

  defp jump_if_true(machine, param1, param2) do
    if read(machine, param1) != 0, do: jump(machine, read(machine, param2)), else: machine
  end

  defp jump_if_false(machine, param1, param2) do
    if read(machine, param1) == 0, do: jump(machine, read(machine, param2)), else: machine
  end

  defp less_than(machine, param1, param2, param3) do
    value = if read(machine, param1) < read(machine, param2), do: 1, else: 0
    write(machine, param3, value)
  end

  defp equals(machine, param1, param2, param3) do
    value = if read(machine, param1) == read(machine, param2), do: 1, else: 0
    write(machine, param3, value)
  end

  defp halt(_machine), do: nil

  defp jump(machine, where), do: %{machine | ip: where}

  defp push_input(machine, value), do: update_in(machine.input, &:queue.in(value, &1))

  defp output(machine), do: List.flatten(machine.output)

  defp write(machine, {_mode, address}, value), do: put_in(machine.memory[address], value)

  defp read(machine, {:positional, address}), do: Map.fetch!(machine.memory, address)

  defp read(_machine, {:immediate, value}), do: value

  defp mem_read(machine, address), do: Map.fetch!(machine.memory, address)

  defp machine() do
    memory =
      Aoc.input_file(2019, 5)
      |> File.read!()
      |> String.trim()
      |> String.split(",")
      |> Stream.with_index()
      |> Stream.map(fn {value, index} -> {index, String.to_integer(value)} end)
      |> Map.new()

    %{memory: memory, ip: 0, input: :queue.new(), output: []}
  end
end
