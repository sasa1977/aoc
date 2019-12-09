defmodule Aoc201909 do
  def run do
    IO.inspect(part1())
    IO.inspect(part2())
  end

  defp part1(), do: machine() |> push_input(1) |> run() |> output()
  defp part2(), do: machine() |> push_input(2) |> run() |> output()

  defp run(machine) do
    machine
    |> Map.put(:state, :ready)
    |> Stream.iterate(&execute_instruction/1)
    |> Stream.drop_while(&(&1.state == :ready))
    |> Enum.at(0)
  end

  defp execute_instruction(%{ip: ip} = machine) do
    code = mem_read(machine, ip)
    {fun, arity} = fun_info(code)

    with %{state: :ready, ip: ^ip} = machine <- apply(fun, [machine | parameters(machine, code, arity)]),
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
  defp param_mode(2), do: :relative

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
      9 => &adjust_relative_base/2,
      99 => &halt/1
    }
  end

  defp add(machine, param1, param2, param3),
    do: write(machine, param3, read(machine, param1) + read(machine, param2))

  defp mul(machine, param1, param2, param3),
    do: write(machine, param3, read(machine, param1) * read(machine, param2))

  defp input(machine, param) do
    case :queue.out(machine.input) do
      {:empty, _queue} ->
        %{machine | state: :awaiting_input}

      {{:value, value}, input} ->
        machine = %{machine | input: input}
        write(machine, param, value)
    end
  end

  defp output(machine, param) do
    output = read(machine, param)
    update_in(machine.output, &[&1, output])
  end

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

  defp adjust_relative_base(machine, param),
    do: update_in(machine.relative_base, &(&1 + read(machine, param)))

  defp halt(machine), do: %{machine | state: :halted}

  defp jump(machine, where), do: %{machine | ip: where}

  defp push_input(machine, value), do: update_in(machine.input, &:queue.in(value, &1))
  defp push_inputs(machine, values), do: Enum.reduce(values, machine, &push_input(&2, &1))

  defp pop_outputs(machine), do: {List.flatten(machine.output), %{machine | output: []}}
  defp output(machine), do: List.flatten(machine.output)

  defp write(machine, {:relative, address}, value),
    do: write(machine, {:positional, machine.relative_base + address}, value)

  defp write(machine, {:positional, address}, value), do: put_in(machine.memory[address], value)

  defp read(machine, {:positional, address}), do: mem_read(machine, address)
  defp read(machine, {:relative, address}), do: read(machine, {:positional, machine.relative_base + address})
  defp read(_machine, {:immediate, value}), do: value

  defp mem_read(machine, address) when address >= 0, do: Map.get(machine.memory, address, 0)

  defp machine() do
    %{
      state: :ready,
      ip: 0,
      relative_base: 0,
      memory: initial_memory(),
      input: :queue.new(),
      output: []
    }
  end

  defp initial_memory() do
    Aoc.input_file(2019, 9)
    |> File.read!()
    |> String.trim()
    |> String.split(",")
    |> Stream.with_index()
    |> Stream.map(fn {value, index} -> {index, String.to_integer(value)} end)
    |> Map.new()
  end
end
