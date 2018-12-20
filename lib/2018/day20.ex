defmodule Aoc201820 do
  alias Aoc201820.Parser

  def run() do
    IO.inspect(part1())
    IO.inspect(part2())
  end

  defp part1(), do: final_map() |> Map.values() |> Enum.max()
  defp part2(), do: final_map() |> Map.values() |> Stream.filter(&(&1 >= 1000)) |> Enum.count()

  defp final_map(), do: walk(instructions()).map

  defp instructions(), do: Aoc.input_file(2018, 20) |> File.read!() |> Parser.ast()

  defp walk(instructions, state \\ %{moves: 0, pos: {0, 0}, map: %{}})

  defp walk([], state), do: state

  defp walk([{:choice, :optional, choices} | instructions_after_choices], state) do
    Enum.reduce(
      choices,
      put_in(state.map, walk(instructions_after_choices, state).map),
      fn choice_instructions, previous_state ->
        new_state = walk(choice_instructions, previous_state)

        # This is the key optimization which drastically reduces the number of combinations. If, after applying the
        # instructions of this choice, we end up in a place we've already visited, and the new score is not better than
        # the previous one, there's no need to try instructions after choices (we've already tried them with a better
        # score).
        map =
          if Map.has_key?(previous_state.map, new_state.pos) and new_state.moves >= previous_state.moves,
            do: new_state.map,
            else: walk(instructions_after_choices, new_state).map

        put_in(previous_state.map, map)
      end
    )
  end

  defp walk([{:choice, :mandatory, choices} | instruction_after_choices], state) do
    # We could apply a similar optimization to the one in the :optional branch. However, the optimization would have to
    # be a bit different: for the best score of every end position we'd need to walk through remaining choices.
    # Since the :optional optimization reduced the running time considerably, this branch is left unoptimized.
    Enum.reduce(
      choices,
      state,
      fn choice_instructions, original_state ->
        new_state = walk(choice_instructions, original_state)
        map = walk(instruction_after_choices, new_state).map
        put_in(original_state.map, map)
      end
    )
  end

  defp walk([{:move, directions} | remaining_instructions], state) do
    state = apply_moves(directions, state)
    walk(remaining_instructions, state)
  end

  defp apply_moves(moves, state), do: Enum.reduce(moves, state, &apply_move(&2, &1))

  defp apply_move(state, direction) do
    moves = state.moves + 1
    pos = move(state.pos, direction) |> move(direction)
    map = Map.update(state.map, pos, moves, &min(&1, moves))
    %{state | moves: moves, pos: pos, map: map}
  end

  defp move({x, y}, :east), do: {x + 1, y}
  defp move({x, y}, :west), do: {x - 1, y}
  defp move({x, y}, :north), do: {x, y + 1}
  defp move({x, y}, :south), do: {x, y - 1}

  defmodule Parser do
    def ast(string), do: string |> tokens() |> build_ast()

    defp build_ast([:route_start | tokens]) do
      {ast, [:route_end]} = route(tokens)
      ast
    end

    defp route(tokens) do
      with {element, tokens} <- route_element(tokens) do
        case route(tokens) do
          nil -> {[element], tokens}
          {other_elements, tokens} -> {[element | other_elements], tokens}
        end
      end
    end

    defp route_element([{:move, _} | _] = tokens) do
      {moves, tokens} = Enum.split_while(tokens, &match?({:move, _}, &1))
      directions = Enum.map(moves, fn {:move, direction} -> direction end)
      {{:move, directions}, tokens}
    end

    defp route_element([:choice_start | tokens]) do
      {routes, tokens} = routes(tokens)

      case tokens do
        [:or, :choice_end | tokens] -> {{:choice, :optional, routes}, tokens}
        [:choice_end | tokens] -> {{:choice, :mandatory, routes}, tokens}
      end
    end

    defp route_element(_tokens), do: nil

    defp routes(tokens) do
      with {route, tokens} <- route(tokens) do
        case tokens do
          [:or | tokens] = outer_tokens ->
            case routes(tokens) do
              nil -> {[route], outer_tokens}
              {other_routes, tokens} -> {[route | other_routes], tokens}
            end

          _ ->
            {[route], tokens}
        end
      end
    end

    defp tokens(string), do: string |> String.trim() |> to_charlist() |> Enum.map(&token/1)

    defp token(?^), do: :route_start
    defp token(?$), do: :route_end
    defp token(?(), do: :choice_start
    defp token(?)), do: :choice_end
    defp token(?|), do: :or
    defp token(?N), do: {:move, :north}
    defp token(?S), do: {:move, :south}
    defp token(?E), do: {:move, :east}
    defp token(?W), do: {:move, :west}
  end
end
