defmodule Aoc201809 do
  alias __MODULE__.CircularList

  def run() do
    play(479, 71035) |> max_score() |> IO.puts()
    play(479, 7_103_500) |> max_score() |> IO.puts()
  end

  defp play(num_players, num_marbles) do
    Enum.reduce(
      1..num_marbles,
      %{circle: CircularList.new([0]), current_player: 0, num_players: num_players, scores: %{}},
      &make_move(&2, &1)
    )
  end

  defp max_score(game_state), do: game_state.scores |> Map.values() |> Enum.max()

  defp make_move(game, marble) when rem(marble, 23) == 0 do
    circle = Enum.reduce(1..7, game.circle, fn _, circle -> CircularList.previous(circle) end)
    {scored, circle} = CircularList.pop(circle)
    scores = Map.update(game.scores, game.current_player, scored + marble, &(&1 + scored + marble))
    next_player(%{game | circle: circle, scores: scores})
  end

  defp make_move(game, marble) do
    circle = game.circle |> CircularList.next() |> CircularList.next() |> CircularList.insert(marble)
    next_player(%{game | circle: circle})
  end

  defp next_player(game), do: %{game | current_player: rem(game.current_player + 1, game.num_players)}

  defmodule CircularList do
    def new(elements), do: {elements, []}

    def next({[], previous}), do: next({Enum.reverse(previous), []})
    def next({[current | rest], previous}), do: {rest, [current | previous]}

    def previous({next, []}), do: previous({[], Enum.reverse(next)})
    def previous({next, [last | rest]}), do: {[last | next], rest}

    def insert({next, previous}, element), do: {[element | next], previous}

    def pop({[], previous}), do: pop({Enum.reverse(previous), []})
    def pop({[current | rest], previous}), do: {current, {rest, previous}}
  end
end
