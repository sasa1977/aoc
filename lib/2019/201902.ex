defmodule Aoc201902 do
  def run do
    IO.inspect(part1())
    IO.inspect(part2())
  end

  defp part1, do: run(%{noun: 12, verb: 2})

  defp part2 do
    desired_input =
      for(noun <- 0..99, verb <- 0..99, do: %{noun: noun, verb: verb})
      |> Enum.find(&(run(&1) == 19_690_720))

    100 * desired_input.noun + desired_input.verb
  end

  defp run(input) do
    input_program()
    |> write(1, input.noun)
    |> write(2, input.verb)
    |> program_states()
    |> Enum.at(-1)
    |> read(0)
  end

  defp program_states(program) do
    program
    |> Stream.iterate(&next_state/1)
    |> Stream.take_while(&(not is_nil(&1)))
  end

  defp next_state(program) do
    {[code], program} = get_next(program, 1)
    execute_instruction(program, code)
  end

  defp execute_instruction(program, code) do
    fun = Map.fetch!(instruction_table(), code)
    {:arity, arity} = Function.info(fun, :arity)
    {parameters, program} = get_next(program, arity - 1)
    apply(fun, [program | parameters])
  end

  defp instruction_table() do
    %{
      1 => &add/4,
      2 => &mul/4,
      99 => &halt/1
    }
  end

  defp add(program, addr1, addr2, addr3) do
    result = read(program, addr1) + read(program, addr2)
    write(program, addr3, result)
  end

  defp mul(program, addr1, addr2, addr3) do
    result = read(program, addr1) * read(program, addr2)
    write(program, addr3, result)
  end

  defp halt(_program), do: nil

  defp write(program, address, value), do: put_in(program.memory[address], value)
  defp read(program, address), do: Map.fetch!(program.memory, address)

  defp get_next(program, 0), do: {[], program}

  defp get_next(program, count) do
    Enum.flat_map_reduce(1..count, program, fn _, program ->
      value = read(program, program.ip)
      program = update_in(program.ip, &(&1 + 1))
      {[value], program}
    end)
  end

  defp input_program() do
    memory =
      Aoc.input_file(__MODULE__)
      |> File.read!()
      |> String.trim()
      |> String.split(",")
      |> Stream.with_index()
      |> Stream.map(fn {value, index} -> {index, String.to_integer(value)} end)
      |> Map.new()

    %{memory: memory, ip: 0}
  end
end
