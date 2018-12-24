defmodule Aoc201824 do
  def run() do
    IO.puts(part1())
    IO.puts(part2())
  end

  defp part1(), do: groups() |> fight_until_finished() |> score()

  defp part2() do
    groups()
    |> Stream.iterate(&boost_immune_system/1)
    |> Stream.map(&fight_until_finished/1)
    |> Enum.find(&(armies(&1) == ["Immune System"]))
    |> score()
  end

  defp boost_immune_system(groups) do
    {immune, infections} = Enum.split_with(Map.values(groups), &(&1.army == "Immune System"))
    immune = Enum.map(immune, &%{&1 | damage: &1.damage + 1})
    Map.new(Stream.map(immune ++ infections, &{group_id(&1), &1}))
  end

  defp fight_until_finished(groups), do: groups |> Stream.iterate(&fight/1) |> Enum.find(&finished?/1)

  defp armies(groups), do: groups |> Map.values() |> Stream.map(& &1.army) |> Enum.uniq()
  defp score(groups), do: groups |> Map.values() |> Stream.map(& &1.units) |> Enum.sum()

  defp finished?(groups), do: Enum.empty?(attackers(groups)) or Enum.count(armies(groups)) < 2

  defp fight(groups) do
    groups
    |> attackers()
    |> Enum.to_list()
    |> Enum.sort_by(fn {attacker_id, _defender_id} -> group(groups, attacker_id).initiative end, &>=/2)
    |> Enum.reduce(groups, fn {attacker_id, defender_id}, groups -> attack(groups, attacker_id, defender_id) end)
  end

  defp attackers(groups) do
    {_attackable, attack_pairs} =
      groups
      |> Map.values()
      |> Enum.sort_by(&{effective_power(&1), &1.initiative}, &>=/2)
      |> Enum.reduce({Enum.group_by(Map.values(groups), & &1.army), []}, &pick_target/2)

    attack_pairs
  end

  defp pick_target(attacker, {attackable, attack_pairs}) do
    enemy_army = enemy_army(attacker.army)
    enemies = Map.get(attackable, enemy_army, [])

    enemies
    |> Stream.reject(&(inflicted_damage(attacker, &1) == 0))
    |> Enum.max_by(&{inflicted_damage(attacker, &1), effective_power(&1), &1.initiative}, fn -> nil end)
    |> case do
      nil ->
        {attackable, attack_pairs}

      defender ->
        attackable = Map.update!(attackable, enemy_army, &Enum.reject(&1, fn group -> group.id == defender.id end))

        attack_pairs =
          if div(inflicted_damage(attacker, defender), defender.hit_points) == 0,
            do: attack_pairs,
            else: [{group_id(attacker), group_id(defender)} | attack_pairs]

        {attackable, attack_pairs}
    end
  end

  defp attack(groups, attacker_id, defender_id) do
    case Map.fetch(groups, attacker_id) do
      {:ok, attacker} ->
        defender = Map.fetch!(groups, defender_id)

        case absorb_damage(defender, attacker) do
          %{units: 0} -> Map.delete(groups, defender_id)
          defender -> Map.put(groups, defender_id, defender)
        end

      :error ->
        groups
    end
  end

  defp absorb_damage(defender, attacker),
    do: update_in(defender.units, &max(0, &1 - div(inflicted_damage(attacker, defender), defender.hit_points)))

  defp inflicted_damage(attacker, defender) do
    cond do
      MapSet.member?(defender.immunities, attacker.damage_type) -> 0
      MapSet.member?(defender.weaknesses, attacker.damage_type) -> effective_power(attacker) * 2
      true -> effective_power(attacker)
    end
  end

  defp enemy_army("Immune System"), do: "Infection"
  defp enemy_army("Infection"), do: "Immune System"

  defp group_id(group), do: {group.army, group.id}
  defp group(groups, group_id), do: Map.fetch!(groups, group_id)

  defp effective_power(group), do: group.units * group.damage

  defp groups() do
    Aoc.input_file(2018, 24)
    |> File.read!()
    |> String.trim()
    |> String.split("\n\n")
    |> Stream.flat_map(&parse_groups/1)
    |> Enum.map(&{group_id(&1), &1})
    |> Map.new()
  end

  defp parse_groups(army) do
    [name, groups] = String.split(army, ":\n")

    groups
    |> String.split("\n")
    |> Stream.with_index(1)
    |> Enum.map(fn {group, id} -> parse_group(group, id, name) end)
  end

  defp parse_group(group, id, army_name) do
    captures =
      [
        ~S/(?<units>\d+) units/,
        ~S/each with (?<hit_points>\d+) hit points(\s\((?<immunities_and_weaknesses>.+)\))?/,
        ~S/with an attack that does (?<damage>\d+) (?<damage_type>\w+) damage/,
        ~S/at initiative (?<initiative>\d+)/
      ]
      |> Enum.join(" ")
      |> Regex.compile!()
      |> Regex.named_captures(group)

    if captures == nil do
      IO.puts(group)
      System.halt()
    end

    immunities_and_weaknesses =
      case Map.fetch!(captures, "immunities_and_weaknesses") do
        "" ->
          %{}

        immunities_and_weaknesses ->
          immunities_and_weaknesses
          |> String.split(~r/;\s*/)
          |> Enum.flat_map(&parse_immunities_and_weaknesses/1)
          |> Enum.group_by(fn {kind, _action} -> kind end, fn {_kind, action} -> action end)
      end

    immunities = Map.get(immunities_and_weaknesses, "immune", [])
    weaknesses = Map.get(immunities_and_weaknesses, "weak", [])

    %{
      id: id,
      army: army_name,
      units: String.to_integer(Map.fetch!(captures, "units")),
      hit_points: String.to_integer(Map.fetch!(captures, "hit_points")),
      initiative: String.to_integer(Map.fetch!(captures, "initiative")),
      damage: String.to_integer(Map.fetch!(captures, "damage")),
      damage_type: Map.fetch!(captures, "damage_type"),
      immunities: MapSet.new(immunities),
      weaknesses: MapSet.new(weaknesses)
    }
  end

  defp parse_immunities_and_weaknesses(immunities_and_weaknesses) do
    %{"kind" => kind, "actions" => actions} =
      Regex.named_captures(~r/(?<kind>\w+) to (?<actions>.+)/, immunities_and_weaknesses)

    actions
    |> String.split(~r/,\s*/)
    |> Enum.map(&{kind, &1})
  end
end
