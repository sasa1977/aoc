defmodule Aoc201820 do
  alias Aoc201820.Parser

  def run() do
    IO.puts(part1())
    IO.puts(part2())
  end

  defp part1(), do: final_map() |> Map.values() |> Enum.max()
  defp part2(), do: final_map() |> Map.values() |> Stream.filter(&(&1 >= 1000)) |> Enum.count()

  defp final_map(), do: walk(instructions()).map

  defp instructions(), do: Aoc.input_file(2018, 20) |> File.read!() |> Parser.ast()

  defp walk(state \\ %{positions: MapSet.new([{0, 0}]), map: %{{0, 0} => 0}}, instructions),
    do: Enum.reduce(instructions, state, &apply_instruction/2)

  defp apply_instruction({:move, directions}, state), do: Enum.reduce(directions, state, &move/2)
  defp apply_instruction({:choice, type, choices}, state), do: explore_choices(type, choices, state)

  defp move(direction, state) do
    new_positions =
      state.positions
      |> Stream.map(&{&1, Map.fetch!(state.map, &1)})
      |> Enum.map(fn {pos, distance} -> {offset(pos, direction), distance + 1} end)

    # Only putting the new positions into the map. If a position already exists, the stored distance is surely smaller
    # than the one we have here.
    map = Enum.reduce(new_positions, state.map, fn {pos, distance}, map -> Map.put_new(map, pos, distance) end)
    new_positions = new_positions |> Stream.map(fn {pos, _distance} -> pos end) |> MapSet.new()

    %{state | map: map, positions: new_positions}
  end

  defp offset({x, y}, :east), do: {x + 1, y}
  defp offset({x, y}, :west), do: {x - 1, y}
  defp offset({x, y}, :north), do: {x, y + 1}
  defp offset({x, y}, :south), do: {x, y - 1}

  defp explore_choices(choices_type, choices, state_before_choice) do
    Enum.reduce(
      choices,
      if(choices_type == :optional, do: state_before_choice, else: %{state_before_choice | positions: MapSet.new()}),
      fn choice, state ->
        %{state | positions: state_before_choice.positions}
        |> walk(choice)
        |> merge_positions(state)
      end
    )
  end

  defp merge_positions(target_state, source_state),
    do: update_in(target_state.positions, &MapSet.union(&1, source_state.positions))

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
      {distance, tokens} = Enum.split_while(tokens, &match?({:move, _}, &1))
      directions = Enum.map(distance, fn {:move, direction} -> direction end)
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
