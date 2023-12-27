defmodule Rocks do
  def parse_line(s) do
    String.trim(s) |> to_charlist() |> Enum.map(fn v ->
      case v do
	?. -> ?.
	?O -> ?O
	?X -> ?X
	?# -> ?X
      end
    end)
  end
  def parse_file(path) do
    File.stream!(path) |> Enum.map(&parse_line/1)
  end
  def transpose(image) do
    Enum.zip(image) |> Enum.map(&Tuple.to_list/1)
  end
  def shift_to_head(list, spaces \\ 0, acc \\ []) do
    case list do
      [] ->
	Enum.reverse(List.duplicate(?., spaces) ++ acc)
      [?. | rest] ->
	shift_to_head(rest, spaces + 1, acc)
      [?O | rest] ->
	shift_to_head(rest, spaces, [?O | acc])
      [?X | rest] ->
	shift_to_head(rest, 0, [?X | List.duplicate(?., spaces)] ++ acc)
    end
  end
  def shift_to_tail(list) do
    Enum.reverse(shift_to_head(Enum.reverse(list)))
  end
  def roll_north(image) do
    transpose(image) |> Enum.map(&shift_to_head/1) |> transpose()
  end
  def roll_south(image) do
    transpose(image) |> Enum.map(&shift_to_tail/1) |> transpose()
  end
  def roll_west(image) do
    Enum.map(image, &shift_to_head/1)
  end
  def roll_east(image) do
    Enum.map(image, &shift_to_tail/1)
  end
  def north_load(image) do
    dist = length(image)
    Enum.with_index(image, fn row, i ->
      (dist - i) * Enum.reduce(row, 0, fn v, count ->
	case v do
	  ?. -> count
	  ?O -> count + 1
	  ?X -> count
	end
      end)
    end) |> Enum.sum()
  end
  def spin_cycle(image, cycles) do
    if cycles == 0 do
      image
    else
      spun = image |>
	roll_north() |> roll_west() |> roll_south() |> roll_east()
      if spun == image do
	image
      else
	spin_cycle(spun, cycles - 1)
      end
    end
  end
  def analyze_spin_cycle(image, index \\ 1, prev \\ %{}) do
    spun = image |>
      roll_north() |> roll_west() |> roll_south() |> roll_east()
    if Map.has_key?(prev, spun) do
      offset = prev[spun]
      period = index - offset
      {offset, period, spun}
    else
      analyze_spin_cycle(spun, index + 1, Map.put(prev, spun, index))
    end
  end
  def quick_spin_cycle(image, cycles) do
    {offset, period, recur} = analyze_spin_cycle(image)
    if cycles < offset do
      spin_cycle(image, cycles)
    else
      cycles_from_recur = rem(cycles - offset, period)
      spin_cycle(recur, cycles_from_recur)
    end
  end
end

case System.argv() do
  ["1", cycles_str, path] ->
    cycles = String.to_integer(cycles_str)
    image = Rocks.parse_file(path)
    cycled = if cycles == 0 do
      Rocks.roll_north(image)
    else
      Rocks.spin_cycle(image, cycles)
    end
    IO.inspect(Rocks.north_load(cycled))
  ["2", cycles_str, path] ->
    cycles = String.to_integer(cycles_str)
    image = Rocks.parse_file(path)
    cycled = Rocks.quick_spin_cycle(image, cycles)
    IO.inspect(Rocks.north_load(cycled))
  _ ->
    :ok
end
