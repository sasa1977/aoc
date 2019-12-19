defmodule Aoc201917 do
  alias __MODULE__.Intcode

  def run do
    Aoc.output(&part1/0)
    Aoc.output(&part2/0)
  end

  defp part1 do
    map().intersections
    |> Stream.map(fn {x, y} -> x * y end)
    |> Enum.sum()
  end

  defp part2() do
    map = map()
    program = find_program(map)
    functions = Enum.uniq(program)
    routine_map = Map.new(Enum.zip(functions, [?A, ?B, ?C]))
    main_routine = program |> Enum.map(&Map.fetch!(routine_map, &1)) |> Enum.intersperse(?,)

    encoded_functions = Enum.map(functions, &encode_function/1)

    inputs =
      [[main_routine], encoded_functions, [?n, ?\n]]
      |> Stream.concat()
      |> Enum.intersperse(?\n)
      |> List.flatten()

    Intcode.new(__MODULE__)
    |> Intcode.write_mem(0, 2)
    |> Intcode.run(inputs)
    |> Intcode.outputs()
    |> List.last()
  end

  defp encode_function(instructions) do
    instructions
    |> Stream.map(fn {direction, steps} ->
      [encoded_direction(direction), ?, | Enum.map(Integer.digits(steps), &(&1 + ?0))]
    end)
    |> Enum.intersperse(?,)
  end

  defp encoded_direction(:left), do: ?L
  defp encoded_direction(:right), do: ?R

  defp find_program(map, breadcrumbs \\ []) do
    map = Map.update!(map, :visited, &MapSet.put(&1, map.robot.at))
    breadcrumbs = [map | breadcrumbs]

    [map | Enum.map([:left, :right], &turn(map, &1))]
    |> Stream.map(&advance/1)
    |> Enum.filter(&(at_scaffold?(&1) and not visited?(&1)))
    |> case do
      # nowhere to go, so this is the end of the current search path
      [] ->
        # if all of the scaffolds have been traversed
        if MapSet.size(map.visited) == MapSet.size(map.scaffolds) do
          # try to find a valid program
          breadcrumbs
          |> Enum.reverse()
          |> to_directions()
          |> programs()
          |> Stream.reject(&is_nil/1)
          |> Enum.find(&valid_program?/1)
        end

      # we still have places to go -> search deeper
      maps ->
        Enum.find_value(maps, &find_program(&1, breadcrumbs))
    end
  end

  defp valid_program?(program),
    do: Enum.all?(program, &(String.length(to_string(encode_function(&1))) <= 20))

  defp advance(map), do: Map.update!(map, :robot, &advance_robot/1)

  defp turn(map, direction), do: update_in(map.robot.facing, &new_direction(&1, direction))

  defp advance_robot(%{facing: :up} = robot), do: Map.update!(robot, :at, fn {x, y} -> {x, y - 1} end)
  defp advance_robot(%{facing: :down} = robot), do: Map.update!(robot, :at, fn {x, y} -> {x, y + 1} end)
  defp advance_robot(%{facing: :left} = robot), do: Map.update!(robot, :at, fn {x, y} -> {x - 1, y} end)
  defp advance_robot(%{facing: :right} = robot), do: Map.update!(robot, :at, fn {x, y} -> {x + 1, y} end)

  defp at_intersection?(map), do: MapSet.member?(map.intersections, map.robot.at)
  defp at_scaffold?(map), do: MapSet.member?(map.scaffolds, map.robot.at)
  defp visited?(map), do: MapSet.member?(map.visited, map.robot.at) and not at_intersection?(map)

  for [from, turn, to] <- [
        ~w/up left left/a,
        ~w/up right right/a,
        ~w/down left right/a,
        ~w/down right left/a,
        ~w/left left down/a,
        ~w/left right up/a,
        ~w/right left up/a,
        ~w/right right down/a
      ] do
    defp new_direction(unquote(from), unquote(turn)), do: unquote(to)
    defp turn_direction(unquote(from), unquote(to)), do: unquote(turn)
  end

  defp programs(list) do
    len = Enum.count(list)

    for len_a <- 1..(len - 2),
        len_b <- 1..(len - (len_a + 1)),
        len_c <- 1..(len - (len_a + len_b)),
        pos_b <- len_a..(len - len_b - 1),
        pos_c <- (pos_b + len_b)..(len - len_c),
        a = Enum.take(list, len_a),
        b = list |> Enum.drop(pos_b) |> Enum.take(len_b),
        c = list |> Enum.drop(pos_c) |> Enum.take(len_c),
        do: program([a, b, c], list)
  end

  defp program(_routines, []), do: []

  defp program(routines, input) do
    routines
    |> Stream.map(&{&1, split(input, &1)})
    |> Stream.reject(&match?({_routine, nil}, &1))
    |> Enum.find_value(fn {routine, rest_input} ->
      with applied_routines when not is_nil(applied_routines) <- program(routines, rest_input),
           do: [routine | applied_routines]
    end)
  end

  defp split(input, []), do: input
  defp split([head | rest_input], [head | other_directions]), do: split(rest_input, other_directions)
  defp split(_, _), do: nil

  defp to_directions(maps) do
    maps
    |> Enum.map(&{&1.robot.facing, &1.robot.at})
    |> condense()
    |> directions()
  end

  defp condense([last]), do: [last]
  defp condense([{facing, _pos1}, {facing, pos2} | rest]), do: condense([{facing, pos2} | rest])
  defp condense([first | rest]), do: [first | condense(rest)]

  defp directions(points) do
    points
    |> Stream.chunk_every(2, 1, :discard)
    |> Enum.map(fn [{from, {x1, y1}}, {to, {x2, y2}}] ->
      {turn_direction(from, to), abs(x2 - x1) + abs(y2 - y1)}
    end)
  end

  defp map() do
    elements =
      real_map()
      |> String.split("\n")
      |> Stream.with_index()
      |> Enum.flat_map(&elements/1)

    {robot_pos, robot_facing} = Keyword.fetch!(elements, :robot)

    scaffolds = MapSet.new([robot_pos | Keyword.get_values(elements, :scaffold)])

    intersections =
      scaffolds
      |> Stream.filter(&intersection?(scaffolds, &1))
      |> MapSet.new()

    %{
      robot: %{at: robot_pos, facing: robot_facing},
      scaffolds: scaffolds,
      intersections: intersections,
      visited: MapSet.new()
    }
  end

  defp intersection?(scaffolds, {x, y}) do
    for(dx <- -1..1, dy <- -1..1, do: {dx, dy})
    |> Stream.filter(fn {dx, dy} -> dx == 0 or dy == 0 end)
    |> Enum.all?(fn {dx, dy} -> MapSet.member?(scaffolds, {x + dx, y + dy}) end)
  end

  defp elements({line, y}) do
    line
    |> String.to_charlist()
    |> Stream.with_index()
    |> Enum.map(fn
      {?#, x} -> {:scaffold, {x, y}}
      {facing, x} when facing in [?<, ?>, ?v, ?^] -> {:robot, {{x, y}, facing(facing)}}
      {?., x} -> {:open_space, {x, y}}
    end)
  end

  defp facing(?<), do: :left
  defp facing(?>), do: :right
  defp facing(?^), do: :up
  defp facing(?v), do: :down

  defp real_map() do
    Intcode.new(__MODULE__)
    |> Intcode.run()
    |> Intcode.outputs()
    |> to_string()
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
