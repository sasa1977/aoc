defmodule Aoc201915 do
  alias __MODULE__.Intcode

  def run do
    IO.inspect(part1())
    IO.inspect(part2())
  end

  defp part1 do
    trace_steps()
    |> Stream.take_while(&is_nil(&1.oxygen_system_pos))
    |> Enum.count()
  end

  defp part2 do
    map = Enum.find(trace_steps(), &Enum.empty?(&1.tracers))

    %{oxygen_edges: [map.oxygen_system_pos], avoid: MapSet.put(map.walls, map.oxygen_system_pos)}
    |> Stream.iterate(fn expansion_step ->
      for(pos <- expansion_step.oxygen_edges, dir <- ~w/north south east west/a, do: move(pos, dir))
      |> Stream.uniq()
      |> Stream.reject(&MapSet.member?(expansion_step.avoid, &1))
      |> Enum.reduce(
        %{expansion_step | oxygen_edges: []},
        &%{&2 | oxygen_edges: [&1 | &2.oxygen_edges], avoid: MapSet.put(&2.avoid, &1)}
      )
    end)
    |> Enum.find_index(&Enum.empty?(&1.oxygen_edges))
    # Subtract 1, because the area has been filled in the previous step.
    |> Kernel.-(1)
  end

  defp trace_steps do
    computer = Intcode.new(__MODULE__) |> Intcode.run()

    %{tracers: [], visited: MapSet.new(), walls: MapSet.new(), oxygen_system_pos: nil}
    |> add_tracer(%{pos: {0, 0}, computer: computer})
    |> Stream.iterate(fn trace_step ->
      for(robot <- trace_step.tracers, dir <- ~w/north south east west/a, do: {robot, dir, move(robot.pos, dir)})
      |> Stream.uniq_by(fn {_robot, _dir, pos} -> pos end)
      |> Stream.reject(&MapSet.member?(trace_step.visited, &1))
      |> Stream.reject(&MapSet.member?(trace_step.walls, &1))
      |> Enum.reduce(%{trace_step | tracers: []}, &move_robot(&2, &1))
    end)
  end

  defp move_robot(trace_step, {robot, dir, pos}) do
    computer = Intcode.run(robot.computer, [code(dir)])
    {[result], computer} = Intcode.pop_outputs(computer)
    robot = %{robot | pos: pos, computer: computer}

    case result do
      0 -> update_in(trace_step.walls, &MapSet.put(&1, pos))
      1 -> add_tracer(trace_step, robot)
      2 -> trace_step |> add_tracer(robot) |> Map.put(:oxygen_system_pos, pos)
    end
  end

  defp add_tracer(trace_step, robot) do
    if MapSet.member?(trace_step.visited, robot.pos) do
      trace_step
    else
      trace_step
      |> Map.update!(:tracers, &[robot | &1])
      |> Map.update!(:visited, &MapSet.put(&1, robot.pos))
    end
  end

  defp code(:north), do: 1
  defp code(:south), do: 2
  defp code(:west), do: 3
  defp code(:east), do: 4

  defp move({x, y}, :north), do: {x, y + 1}
  defp move({x, y}, :south), do: {x, y - 1}
  defp move({x, y}, :west), do: {x - 1, y}
  defp move({x, y}, :east), do: {x + 1, y}

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
