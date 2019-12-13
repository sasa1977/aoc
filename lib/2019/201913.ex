defmodule Aoc201913 do
  alias __MODULE__.Intcode

  def run do
    IO.inspect(part1())
    IO.inspect(part2())
  end

  defp part1(), do: Enum.count(new_game().blocks)

  defp part2() do
    new_game()
    |> Stream.iterate(&play/1)
    |> Enum.find(&Enum.empty?(&1.blocks))
    |> Map.fetch!(:score)
  end

  defp new_game() do
    {outputs, computer} =
      Intcode.new(__MODULE__)
      |> Intcode.write_mem(0, 2)
      |> run_program()

    %{
      computer: computer,
      blocks: MapSet.new(Keyword.get_values(outputs, :block)),
      paddle: Keyword.fetch!(outputs, :paddle),
      ball: Keyword.fetch!(outputs, :ball),
      score: Keyword.get(outputs, :score, 0)
    }
  end

  defp play(game) do
    next_move = sign(game.ball.x - game.paddle.x)
    {outputs, computer} = run_program(game.computer, [next_move])

    {emptied, updates} = Keyword.split(outputs, [:empty])
    blocks = emptied |> Keyword.values() |> Enum.reduce(game.blocks, &MapSet.delete(&2, &1))
    Map.merge(%{game | computer: computer, blocks: blocks}, Map.new(updates))
  end

  defp sign(0), do: 0
  defp sign(pos) when pos > 0, do: 1
  defp sign(pos) when pos < 0, do: -1

  defp run_program(computer, inputs \\ []) do
    computer = Intcode.run(computer, inputs)
    {outputs, computer} = Intcode.pop_outputs(computer)
    {decode_outputs(outputs), computer}
  end

  defp decode_outputs(outputs) do
    outputs
    |> Stream.chunk_every(3)
    |> Enum.map(fn
      [-1, 0, score] -> {:score, score}
      [x, y, tile_id] -> {tile_type(tile_id), %{x: x, y: y}}
    end)
  end

  defp tile_type(0), do: :empty
  defp tile_type(1), do: :wall
  defp tile_type(2), do: :block
  defp tile_type(3), do: :paddle
  defp tile_type(4), do: :ball

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
