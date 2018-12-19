defmodule Aoc201819 do
  def run() do
    IO.inspect(part1(program()))
    IO.inspect(part2(program()))
  end

  defp part1(program) do
    program
    |> new_machine()
    |> Stream.iterate(&exec_next_instruction/1)
    |> Enum.find(&halted?/1)
    |> get_reg(0)
  end

  defp part2(program) do
    # This is obtained by reverse engineering the input program. Therefore, this code won't work for other inputs.
    # After reverse engineering the program  (you can find pseudoassembly equivalent in the input file), I've
    # established that it does the following:
    # - If the first registry is set to 1, the program first computes the input number and puts it to registry E (r4).
    # - The program then starts looping from the instruction 1.
    # - The final result in the registry A (r0) will contain the sum of divisors of the input number.

    program
    |> new_machine()
    |> put_reg(0, 1)
    |> Stream.iterate(&exec_next_instruction/1)
    |> Enum.find(&(&1.ip == 1))
    |> get_reg(4)
    |> divisors()
    |> Enum.sum()
  end

  defp divisors(num) do
    Stream.iterate(1, &(&1 + 1))
    |> Stream.take_while(&(&1 * &1 <= num))
    |> Stream.filter(&(rem(num, &1) == 0))
    |> Stream.flat_map(&[&1, div(num, &1)])
    |> Stream.uniq()
  end

  defp program(), do: Enum.map(Aoc.input_lines(2018, 19), &parse_instruction/1)

  defp parse_instruction(<<"#ip ", register>>), do: {:bind_ip, register - ?0}

  defp parse_instruction(<<op::binary-size(4), " ", args::binary>>) do
    args = String.replace(args, ~r/#.*/, "")
    {String.to_existing_atom(op), args |> String.split() |> Enum.map(&String.to_integer/1)}
  end

  defp new_machine([{:bind_ip, register} | instructions]) do
    %{
      ip: 0,
      ip_register: register,
      instructions: List.to_tuple(instructions),
      registers: 0..5 |> Stream.map(&{&1, 0}) |> Map.new()
    }
  end

  defp halted?(machine), do: machine.ip < 0 or machine.ip >= tuple_size(machine.instructions)

  defp exec_next_instruction(machine) do
    machine
    |> put_reg(machine.ip_register, machine.ip)
    |> exec(elem(machine.instructions, machine.ip))
    |> update_ip()
  end

  defp update_ip(machine), do: %{machine | ip: get_reg(machine, machine.ip_register) + 1}

  defp get_reg(machine, pos), do: Map.fetch!(machine.registers, pos)
  defp put_reg(machine, pos, value), do: %{machine | registers: Map.put(machine.registers, pos, value)}

  defp exec(machine, {instruction, [a, b, c]}), do: Map.fetch!(instructions(), instruction).(machine, a, b, c)

  defp instructions() do
    %{
      addr: &put_reg(&1, &4, get_reg(&1, &2) + get_reg(&1, &3)),
      addi: &put_reg(&1, &4, get_reg(&1, &2) + &3),
      mulr: &put_reg(&1, &4, get_reg(&1, &2) * get_reg(&1, &3)),
      muli: &put_reg(&1, &4, get_reg(&1, &2) * &3),
      banr: &put_reg(&1, &4, :erlang.band(get_reg(&1, &2), get_reg(&1, &3))),
      bani: &put_reg(&1, &4, :erlang.band(get_reg(&1, &2), &3)),
      borr: &put_reg(&1, &4, :erlang.bor(get_reg(&1, &2), get_reg(&1, &3))),
      bori: &put_reg(&1, &4, :erlang.bor(get_reg(&1, &2), &3)),
      gtir: &put_reg(&1, &4, if(&2 > get_reg(&1, &3), do: 1, else: 0)),
      gtri: &put_reg(&1, &4, if(get_reg(&1, &2) > &3, do: 1, else: 0)),
      gtrr: &put_reg(&1, &4, if(get_reg(&1, &2) > get_reg(&1, &3), do: 1, else: 0)),
      eqir: &put_reg(&1, &4, if(&2 == get_reg(&1, &3), do: 1, else: 0)),
      eqri: &put_reg(&1, &4, if(get_reg(&1, &2) == &3, do: 1, else: 0)),
      eqrr: &put_reg(&1, &4, if(get_reg(&1, &2) == get_reg(&1, &3), do: 1, else: 0)),
      setr: fn machine, reg_a, _b, reg_c -> put_reg(machine, reg_c, get_reg(machine, reg_a)) end,
      seti: fn machine, val, _b, reg_c -> put_reg(machine, reg_c, val) end
    }
  end
end
