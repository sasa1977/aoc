defmodule Aoc201919 do
  alias __MODULE__.Intcode

  def run do
    Aoc.output(&part1/0)
    Aoc.output(&part2/0)
  end

  defp part1 do
    pulls(50)
    |> Stream.map(& &1.count)
    |> Enum.sum()
  end

  defp part2 do
    square = pulls(10_000) |> largest_squares() |> Enum.find(&(&1.dimension == 100))
    square.x * 10_000 + square.y
  end

  defp largest_squares(pulls) do
    pulls
    |> Stream.chunk_every(100, 1, :discard)
    |> Stream.map(&largest_square/1)
    |> Stream.reject(&is_nil/1)
  end

  defp largest_square(pulls) do
    if Enum.any?(pulls, &(&1.count == 0)) do
      nil
    else
      left = pulls |> Stream.map(& &1.from) |> Enum.max()
      right = pulls |> Stream.map(&(&1.from + &1.count - 1)) |> Enum.min()
      dimension = min(right - left + 1, length(pulls))
      %{y: hd(pulls).y, x: left, dimension: dimension}
    end
  end

  defp pulls(size) do
    computer = Intcode.new(__MODULE__)

    Stream.unfold(
      {0, 0, 0},
      fn {y, start_x, last_count} ->
        # assume that the pull start is shifted to the right at most once
        max_x = start_x + 2

        offset = Enum.find_index(statuses(computer, y, start_x, max_x), &(&1 == :pull))

        if is_nil(offset) do
          {%{y: y, from: nil, count: 0}, {y + 1, start_x, last_count}}
        else
          from = start_x + offset
          start_scan = min(start_x + last_count, size - 1)

          count =
            statuses(computer, y, start_scan, size)
            |> Stream.take_while(&(&1 == :pull))
            |> Enum.count()

          final_count = count + start_scan - from
          {%{y: y, from: from, count: final_count}, {y + 1, from, final_count}}
        end
      end
    )
    |> Stream.take(size)
  end

  defp statuses(computer, y, from, size) do
    from
    |> Stream.iterate(&(&1 + 1))
    |> Stream.take_while(&(&1 < size))
    |> Stream.map(&status(computer, {&1, y}))
  end

  defp status(computer, {x, y}) do
    case computer |> Intcode.run([x, y]) |> Intcode.outputs() do
      [0] -> :stationary
      [1] -> :pull
    end
  end

  defmodule Intcode do
    # ------------------------------------------------------------------------
    # API
    # ------------------------------------------------------------------------

    def new(module) do
      %{
        state: :ready,
        ip: 0,
        relative_base: 0,
        memory: initial_memory(module),
        input: :queue.new(),
        output: []
      }
    end

    def run(%{state: state} = computer, inputs \\ []) when state in [:ready, :awaiting_input] do
      computer
      |> push_inputs(inputs)
      |> Stream.iterate(&execute_instruction/1)
      |> Enum.find(&(&1.state != :ready))
    end

    def outputs(computer), do: List.flatten(computer.output)

    def pop_outputs(computer), do: {outputs(computer), %{computer | output: []}}

    def write_mem(computer, address, value), do: put_in(computer.memory[address], value)

    # ------------------------------------------------------------------------
    # Instructions
    # ------------------------------------------------------------------------

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

    defp add(computer, param1, param2, param3),
      do: write(computer, param3, read(computer, param1) + read(computer, param2))

    defp mul(computer, param1, param2, param3),
      do: write(computer, param3, read(computer, param1) * read(computer, param2))

    defp input(computer, param) do
      case :queue.out(computer.input) do
        {:empty, _queue} ->
          %{computer | state: :awaiting_input}

        {{:value, value}, input} ->
          computer = %{computer | input: input}
          write(computer, param, value)
      end
    end

    defp output(computer, param) do
      output = read(computer, param)
      update_in(computer.output, &[&1, output])
    end

    defp jump_if_true(computer, param1, param2) do
      if read(computer, param1) != 0, do: jump(computer, read(computer, param2)), else: computer
    end

    defp jump_if_false(computer, param1, param2) do
      if read(computer, param1) == 0, do: jump(computer, read(computer, param2)), else: computer
    end

    defp less_than(computer, param1, param2, param3) do
      value = if read(computer, param1) < read(computer, param2), do: 1, else: 0
      write(computer, param3, value)
    end

    defp equals(computer, param1, param2, param3) do
      value = if read(computer, param1) == read(computer, param2), do: 1, else: 0
      write(computer, param3, value)
    end

    defp adjust_relative_base(computer, param),
      do: update_in(computer.relative_base, &(&1 + read(computer, param)))

    defp halt(computer), do: %{computer | state: :halted}

    # ------------------------------------------------------------------------
    # Private
    # ------------------------------------------------------------------------

    defp execute_instruction(%{ip: ip} = computer) do
      code = mem_read(computer, ip)
      {fun, arity} = fun_info(code)

      with %{state: :ready, ip: ^ip} = computer <- apply(fun, [computer | parameters(computer, code, arity)]),
           do: update_in(computer.ip, &(&1 + arity + 1))
    end

    defp fun_info(code) do
      opcode = rem(code, 100)
      fun = Map.fetch!(instruction_table(), opcode)
      {:arity, arity} = Function.info(fun, :arity)
      {fun, arity - 1}
    end

    defp parameters(computer, code, arity) do
      Stream.unfold(
        {1, div(code, 100)},
        fn {offset, mode_acc} ->
          value = mem_read(computer, computer.ip + offset)
          mode = param_mode(rem(mode_acc, 10))
          {{mode, value}, {offset + 1, div(mode_acc, 10)}}
        end
      )
      |> Enum.take(arity)
    end

    defp param_mode(0), do: :positional
    defp param_mode(1), do: :immediate
    defp param_mode(2), do: :relative

    defp jump(computer, where), do: %{computer | ip: where}

    defp push_input(computer, value), do: %{computer | input: :queue.in(value, computer.input), state: :ready}
    defp push_inputs(computer, values), do: Enum.reduce(values, computer, &push_input(&2, &1))

    defp write(computer, address, value), do: put_in(computer.memory[param_addr(computer, address)], value)

    defp read(_computer, {:immediate, value}), do: value
    defp read(computer, address), do: mem_read(computer, param_addr(computer, address))

    defp param_addr(_computer, {:positional, address}), do: address
    defp param_addr(computer, {:relative, address}), do: computer.relative_base + address

    defp mem_read(computer, address) when address >= 0, do: Map.get(computer.memory, address, 0)

    defp initial_memory(module) do
      Aoc.input_file(module)
      |> File.read!()
      |> String.trim()
      |> String.split(",")
      |> Stream.with_index()
      |> Stream.map(fn {value, index} -> {index, String.to_integer(value)} end)
      |> Map.new()
    end
  end
end
