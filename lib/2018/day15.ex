defmodule Aoc201815 do
  alias Aoc201815.Board

  def run() do
    IO.puts(part1())
    IO.puts(part2())
  end

  defp part1(), do: %{elf: 3, goblin: 3} |> play_game() |> Board.score()

  defp part2() do
    num_elves = num_units(:elf)

    Stream.iterate(4, &(&1 + 1))
    |> Stream.map(&play_game(%{elf: &1, goblin: 3}))
    |> Enum.find(&(Board.winner(&1) == :elf && Board.num_units(&1) == num_elves))
    |> Board.score()
  end

  defp play_game(attack_powers), do: attack_powers |> all_states() |> Enum.at(-1)

  defp all_states(attack_powers) do
    {elements, units} = parse_input()

    Board.new(elements, units, attack_powers)
    |> Stream.iterate(&Board.next_play/1)
    |> Stream.take_while(&(&1 != :game_over))
  end

  defp num_units(type) do
    {_elements, units} = parse_input()
    units |> Stream.filter(&match?({_pos, ^type}, &1)) |> Enum.count()
  end

  defp parse_input() do
    {elements, units} =
      Aoc.input_lines(2018, 15)
      |> Stream.with_index()
      |> Stream.flat_map(fn {line, y} -> line |> to_charlist() |> Stream.with_index() |> Stream.map(&{&1, y}) end)
      |> Stream.map(fn {{symbol, x}, y} -> parse_symbol(symbol, {y, x}) end)
      |> Enum.unzip()

    {elements, Stream.reject(units, &match?({_pos, nil}, &1))}
  end

  defp parse_symbol(symbol, pos) do
    {{pos, element(symbol)}, {pos, unit(symbol)}}
  end

  defp element(?#), do: :wall
  defp element(?.), do: :open_cavern
  defp element(unit) when unit in [?E, ?G], do: :open_cavern

  defp unit(?E), do: :elf
  defp unit(?G), do: :goblin
  defp unit(_), do: nil

  defmodule Board do
    alias Aoc201815.Unit

    def new(elements, units, attack_powers) do
      %{elements: Map.new(elements), units: build_units(units, attack_powers), next_units: [], round: 0}
    end

    def score(board), do: rounds_played(board) * units_score(board)

    def winner(board) do
      [winner] = board.units |> Map.values() |> Stream.map(& &1.type) |> Enum.uniq()
      winner
    end

    def num_units(board), do: Map.size(board.units)

    def next_play(board) do
      if board.units |> Map.values() |> Stream.map(& &1.type) |> Aoc.EnumHelper.all_same?() do
        :game_over
      else
        board = order_units(board)
        {[unit], next_units} = Enum.split(board.next_units, 1)
        play_unit(%{board | next_units: next_units}, unit)
      end
    end

    def at(board, pos), do: Map.get_lazy(board.units, pos, fn -> Map.fetch!(board.elements, pos) end)

    defp rounds_played(%{next_units: [], round: round}), do: round
    defp rounds_played(%{round: round}), do: round - 1

    defp units_score(board), do: board.units |> Map.values() |> Stream.map(& &1.hit_points) |> Enum.sum()

    defp order_units(board) do
      with %{next_units: []} <- board do
        board
        |> put_in([:next_units], board.units |> Map.values() |> Enum.sort_by(& &1.pos))
        |> update_in([:round], &(&1 + 1))
      end
    end

    defp build_units(units, attack_powers) do
      units
      |> Stream.with_index()
      |> Stream.map(fn {{pos, type}, id} -> {pos, Unit.new(id, type, pos, attack_powers)} end)
      |> Map.new()
    end

    defp play_unit(board, unit) do
      case Unit.next_move(unit, board) do
        nil -> board
        {:move, pos} -> move_unit(board, unit, pos)
        :attack -> attack(board, unit)
      end
    end

    defp move_unit(board, unit, pos) do
      previous_pos = unit.pos
      unit = Unit.move(unit, pos)
      board = update_in(board.units, &(&1 |> Map.delete(previous_pos) |> Map.put(pos, unit)))
      attack(board, unit)
    end

    defp attack(board, unit) do
      case Unit.enemy_to_attack(unit, board) do
        nil ->
          board

        enemy ->
          enemy = Unit.attacked(enemy, unit)
          board = %{board | next_units: Enum.map(board.next_units, &if(&1.id == enemy.id, do: enemy, else: &1))}
          if Unit.dead?(enemy), do: remove_unit(board, enemy), else: put_in(board.units[enemy.pos], enemy)
      end
    end

    defp remove_unit(board, unit) do
      board
      |> update_in([:units], &Map.delete(&1, unit.pos))
      |> update_in([:next_units], &Enum.reject(&1, fn next_unit -> next_unit.id == unit.id end))
    end
  end

  defmodule Unit do
    alias Aoc201815.Board

    def new(id, type, pos, attack_powers) do
      %{id: id, type: type, pos: pos, hit_points: 200, attack_power: Map.fetch!(attack_powers, type)}
    end

    def move(unit, pos), do: %{unit | pos: pos}

    def attacked(unit, enemy), do: update_in(unit.hit_points, &max(&1 - enemy.attack_power, 0))

    def dead?(unit), do: unit.hit_points == 0

    def enemy_to_attack(unit, board) do
      unit.pos
      |> sorted_adjacent_positions()
      |> Stream.map(&Board.at(board, &1))
      |> Stream.filter(&enemies?(unit, &1))
      |> Enum.min_by(&{&1.hit_points, &1.pos}, fn -> nil end)
    end

    def next_move(unit, board) do
      case shortest_paths_to_enemies(unit, board) do
        [] ->
          nil

        paths ->
          if Enum.any?(paths, &match?([_, _], &1)) do
            :attack
          else
            target_pos = paths |> Stream.map(&hd(tl(&1))) |> Enum.min()
            target_path = Enum.find(paths, &match?([_, ^target_pos | _], &1))
            next_pos = target_path |> Enum.reverse() |> tl() |> hd()
            {:move, next_pos}
          end
      end
    end

    defp shortest_paths_to_enemies(unit, board) do
      {MapSet.new([unit.pos]), [[unit.pos]]}
      |> Stream.iterate(fn {visited, paths} -> expand_paths(unit, board, visited, paths) end)
      |> Stream.map(fn {_visited, paths} -> paths end)
      |> Enum.find_value(nil, fn
        [] ->
          []

        paths ->
          case Enum.filter(paths, &enemies?(unit, Board.at(board, hd(&1)))) do
            [] -> nil
            paths -> paths
          end
      end)
    end

    defp expand_paths(unit, board, visited, paths) do
      {visited, paths} =
        Enum.reduce(
          paths,
          {visited, []},
          fn path, {visited, paths} ->
            case next_path_positions(unit, board, visited, path) do
              [] ->
                {visited, paths}

              next_path_positions ->
                paths = Enum.reduce(next_path_positions, paths, &[[&1 | path] | &2])
                visited = MapSet.union(visited, MapSet.new(next_path_positions))
                {visited, paths}
            end
          end
        )

      {visited, Enum.reverse(paths)}
    end

    defp next_path_positions(unit, board, visited, path) do
      path
      |> hd()
      |> sorted_adjacent_positions()
      |> Stream.filter(&valid_pos?/1)
      |> Stream.reject(&MapSet.member?(visited, &1))
      |> Enum.filter(&valid_move?(&1, unit, board))
    end

    defp sorted_adjacent_positions({y, x}), do: [{y - 1, x}, {y, x - 1}, {y, x + 1}, {y + 1, x}]
    defp valid_pos?({y, x}), do: y >= 0 and x >= 0

    defp valid_move?(pos, unit, board) do
      occupant = Board.at(board, pos)
      occupant == :open_cavern or enemies?(unit, occupant)
    end

    defp enemies?(%{type: type1}, %{type: type2}) when type1 != type2, do: true
    defp enemies?(_, _), do: false
  end
end
