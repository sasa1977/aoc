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

  defp walk(state \\ %{positions: %{{0, 0} => 0}, map: %{}}, instructions),
    do: Enum.reduce(instructions, state, &apply_instruction/2)

  defp apply_instruction({:move, directions}, state), do: Enum.reduce(directions, state, &move/2)
  defp apply_instruction({:choice, type, choices}, state), do: explore_choices(type, choices, state)

  defp move(direction, state),
    do: merge_positions(%{state | positions: %{}}, state.positions |> Stream.map(&offset(&1, direction)))

  defp offset({{x, y}, distance}, :east), do: {{x + 1, y}, distance + 1}
  defp offset({{x, y}, distance}, :west), do: {{x - 1, y}, distance + 1}
  defp offset({{x, y}, distance}, :north), do: {{x, y + 1}, distance + 1}
  defp offset({{x, y}, distance}, :south), do: {{x, y - 1}, distance + 1}

  defp explore_choices(choices_type, choices, state_before_choice) do
    Enum.reduce(
      choices,
      if(choices_type == :optional, do: state_before_choice, else: %{state_before_choice | positions: %{}}),
      fn choice, state ->
        %{state | positions: state_before_choice.positions}
        |> walk(choice)
        |> merge_positions(state.positions)
      end
    )
  end

  defp merge_positions(state, new_positions) do
    new_positions = new_positions |> Stream.map(&with_shortest_distance(&1, state)) |> Enum.into(state.positions)
    %{state | positions: new_positions, map: Map.merge(state.map, new_positions)}
  end

  defp with_shortest_distance({pos, distance}, state) do
    distance = Enum.min([distance, Map.get(state.map, pos, distance), Map.get(state.positions, pos, distance)])
    {pos, distance}
  end

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
