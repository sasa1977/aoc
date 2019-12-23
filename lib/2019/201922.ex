defmodule Aoc201922 do
  @moduledoc """

  # Part 1

  ## Cyclical space

  The key insight is that a deck of card can be repeated cyclically. So for example, if we have cards 0, 1, and 2,
  we could represent the deck as 0, 1, 2, 0, 1, 2, 0, 1, 2, ...

  In such representation, the card at position 0 is the same as the card at position 3 is the same as the card at
  position 6, and so on. Likewise, the indices can stretch to negatives, so for example the card at position 2
  is the same as the card at position -1, is the same as the card at position -4, and so on.

  More generally, we can say that pos == pos + n * deck_size for any arbitrary integer n.

  ## Linear transformations

  Given such representation, we can express each transformation as a linear function that takes the initial position
  as its argument and returns the new position:

    - deal into new stack: new_pos = -current_pos + deck_size - 1
    - cut: new_pos = current_pos - cut_pos
    - deal with increment: new_pos = increment * current_pos

  Note that these functions can return positions which are not in the range 0..(deck_size - 1), but we can easily
  normalize the resulting positions with `rem(pos, deck_size)` for zero and positive positions, or
  `deck_size - rem(-pos, deck_size)` for negative positions.

  Notice that all of the listed functions are linear, i.e. they can be represented as a*x + b.
  This means that the entire shuffle sequence can be expressed as a single function which is a composition of
  all the steps.

  For example, suppose that we have only three steps in the sequence, called f, g, h. Then the entire transformation
  can be represented as f(g(h(current_pos))). We can build this composition iteratively by composing g and h, and then
  composing f with the result. Given two functions f = a*x+b and g = c*x+d, composition g(f(x)) is c*a*x + c*b + d.

  This is all we need to solve part 1. We read the input, and build a collection of `{a, b}` pairs which represent
  each step as a function. Then we build a composition of these steps to produce the function which represents the
  entire transformation. Finally, we apply the function by simply calculating a*2019+b to get the new
  position of 2019 after the entire shuffle has been performed. Remember that we need to normalize the result
  to fall in the range of 0..(deck_size - 1).

  # Part 2

  ## Normalizing functions

  One challenge in part 2 is that we have to iteratively apply the function many times. The problem we'll encounter
  here is that a and b values in the function are going to be very large. Applying the function iteratively will
  generate even larger numbers. Although in Elixir numbers are bound only by memory, this will still not work, because
  calculations will become too slow.

  Therefore, we need to normalize a and b. As it turns out, this can be done quite easily. In our cyclical space,
  a function a*pos+b will generate the same position (after normalization) as the function
  (a + n*deck_size)*x + b + m*deck_size for any arbitrary pair of integers n and m. In other words, we can
  arbitrarily (and independently!) increment or decrement a and b by some multiple of deck_size.

  I have no clue which theorem defines this, but it can be informally proven. Consider again the expanded version
  (a + n*deck_size)*x + b + m*deck_size. This can be rewritten as a*x + b + deck_size * (n*x + b + m).
  We know that (n*x + b + m) is an integer (since all values are integers), and we know from before that
  pos == pos + n * deck_size for any integer n, which means that these two functions will always produce the same
  position (again, after the output positions are normalized).

  Armed with that knowledge, we can normalize each function `{a, b}` into
  `{normalize(a, deck_size), normalize(b, deck_size)}`, where `normalize` is basically `rem` with a special handling
  of negative values, as explained earlier.

  To summarize, when we compose functions, we'll normalize the vectors. Likewise, after computing new positions,
  we'll normalize their values. Thus, all the values we work with will always be in the range of 0..(deck_size - 1).

  ## Inverting the direction

  Another challenge of part 2 is that we have to find the value that ends up in position 2020. However, our function
  works in the opposite direction - it computes the new position from the previous one. To solve this, we need
  to inverse the shuffle function.

  An inverse of a linear function a*x + b is 1/a - b/a (obtained by swapping x and y in the original function
  definition, and transforming to standard representation). To make sure we don't end up with floats,
  we need to increase 1 and b (by repeatedly adding deck_size) to make sure the inverse function
  coefficients are still integers.

  With these ideas in place, the inverse of the shuffle is computed as follows:

    1. Read the input
    2. Produce functions as in part 1
    3. Reverse the list of functions
    4. Invert each function
    5. Calculate the composition as in part 1

  The output is again a function which works in the opposite direction. It takes `next_pos` as its argument and returns
  `previous_pos`.

  ## Applying the function many times

  To apply the function n times, we can simply compose it with it self. A shuffle applied 4 times is f(f(f(f(x)))).
  Unfortunately, the number of steps is quite large (101_741_582_076_661), so this won't finish in a reasonable
  amount of time. To speed things up, we can use the technique called exponentiation by squaring
  (https://en.wikipedia.org/wiki/Exponentiation_by_squaring).

  For example to produce the function which performs the shuffle sequence 100 times, we can do the following:

  1. f2(x) = f(f(x))
  2. f4(x) = f2(f2(x))
  3. f8(x) = f4(f4(x))
  4. f16(x) = f8(f8(x))
  5. f32(x) = f16(f16(x))
  6. f64(x) = f32(f32(x))
  7. f100(x) = f64(f32(f4(x)))

  So instead of performing 100 compositions, we only did 7. For 101_741_582_076_661 steps we'll only need about
  100 compositions, which can be done quickly.
  """
  import Kernel, except: [apply: 3]

  def run do
    Aoc.output(&part1/0)
    Aoc.output(&part2/0)
  end

  defp part1 do
    deck_size = 10_007
    function = shuffle_function(deck_size)
    apply(function, 2019, deck_size)
  end

  defp part2 do
    deck_size = 119_315_717_514_047
    steps = 101_741_582_076_661

    inverse_shuffle(deck_size)
    |> applied_many_times(steps, deck_size)
    |> apply(2020, deck_size)
  end

  defp apply({a, b}, x, deck_size), do: normalize(a * x + b, deck_size)

  defp applied_many_times(function, count, deck_size) do
    binary_digits = count |> Integer.to_string(2) |> to_charlist() |> Stream.map(&(&1 - ?0))
    functions = Stream.iterate(function, &compose(&1, &1, deck_size))

    binary_digits
    |> Enum.reverse()
    |> Stream.zip(functions)
    |> Stream.reject(fn {digit, _function} -> digit == 0 end)
    |> Stream.map(fn {_digit, function} -> function end)
    |> Enum.reduce(&compose(&1, &2, deck_size))
  end

  defp compose({ga, gb}, {fa, fb}, deck_size),
    do: {normalize(ga * fa, deck_size), normalize(ga * fb + gb, deck_size)}

  defp shuffle_function(deck_size), do: Enum.reduce(functions(deck_size), &compose(&1, &2, deck_size))

  defp inverse_shuffle(deck_size) do
    functions(deck_size)
    |> Stream.map(&inverse(&1, deck_size))
    |> Enum.reduce(&compose(&2, &1, deck_size))
  end

  defp functions(deck_size), do: Stream.map(Aoc.input_lines(__MODULE__), &function(&1, deck_size))

  defp function("deal into new stack", deck_size), do: {-1, deck_size - 1}
  defp function("cut " <> position, _deck_size), do: {1, -String.to_integer(position)}
  defp function("deal with increment " <> step, _deck_size), do: {String.to_integer(step), 0}

  defp inverse({a, b}, deck_size),
    do: {normalized_div(1, a, deck_size), normalized_div(-b, a, deck_size)}

  defp normalized_div(a, b, deck_size) do
    a
    |> Stream.iterate(&(&1 + deck_size))
    |> Enum.find(&(rem(&1, b) == 0))
    |> div(b)
    |> normalize(deck_size)
  end

  defp normalize(pos, deck_size) when pos < 0, do: deck_size - normalize(-pos, deck_size)
  defp normalize(pos, deck_size), do: rem(pos, deck_size)
end
