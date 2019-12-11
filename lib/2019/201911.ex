defmodule Aoc201911 do
  alias __MODULE__.Intcode

  def run do
    IO.inspect(part1())
    IO.puts(part2())
  end

  defp part1() do
    robot()
    |> run()
    |> painted_locations()
    |> Enum.count()
  end

  defp part2() do
    robot()
    |> paint_current_location(1)
    |> run()
    |> painted_image()
  end

  defp painted_image(robot) do
    {x1, x2} = Enum.min_max(robot.grid |> Map.keys() |> Stream.map(& &1.x))
    {y1, y2} = Enum.min_max(robot.grid |> Map.keys() |> Stream.map(& &1.y))

    y1..y2
    |> Stream.map(&painted_row(robot, &1, x1, x2))
    |> Enum.intersperse(?\n)
  end

  defp painted_row(robot, y, x1, x2) do
    x1..x2
    |> Stream.map(&color(robot, %{x: &1, y: y}))
    |> Enum.map(&Map.fetch!(%{0 => " ", 1 => "*"}, &1))
  end

  defp robot do
    %{
      computer: Intcode.new(__MODULE__),
      location: %{x: 0, y: 0},
      grid: %{},
      facing: :up
    }
  end

  defp painted_locations(robot), do: robot.grid

  defp run(robot) do
    robot
    |> Stream.iterate(&run_until_paused/1)
    |> Enum.find(&(&1.computer.state == :halted))
  end

  defp run_until_paused(robot) do
    computer = Intcode.run(robot.computer, [current_color(robot)])
    {[color, direction], computer} = Intcode.pop_outputs(computer)

    %{robot | computer: computer}
    |> paint_current_location(color)
    |> move(direction)
  end

  defp paint_current_location(robot, color), do: put_in(robot.grid[robot.location], color)
  defp color(robot, location), do: Map.get(robot.grid, location, 0)
  defp current_color(robot), do: color(robot, robot.location)

  defp move(robot, dir_code), do: robot |> turn(direction(dir_code)) |> advance()

  defp direction(0), do: :left
  defp direction(1), do: :right

  defp turn(%{facing: :up} = robot, :left), do: %{robot | facing: :left}
  defp turn(%{facing: :up} = robot, :right), do: %{robot | facing: :right}
  defp turn(%{facing: :down} = robot, :left), do: %{robot | facing: :right}
  defp turn(%{facing: :down} = robot, :right), do: %{robot | facing: :left}
  defp turn(%{facing: :left} = robot, :left), do: %{robot | facing: :down}
  defp turn(%{facing: :left} = robot, :right), do: %{robot | facing: :up}
  defp turn(%{facing: :right} = robot, :left), do: %{robot | facing: :up}
  defp turn(%{facing: :right} = robot, :right), do: %{robot | facing: :down}

  defp advance(%{facing: :up} = robot), do: update_in(robot.location.y, &(&1 - 1))
  defp advance(%{facing: :down} = robot), do: update_in(robot.location.y, &(&1 + 1))
  defp advance(%{facing: :left} = robot), do: update_in(robot.location.x, &(&1 - 1))
  defp advance(%{facing: :right} = robot), do: update_in(robot.location.x, &(&1 + 1))

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
