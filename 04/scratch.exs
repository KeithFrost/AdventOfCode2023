defmodule Scratch do
  def parse_nums(s) do
    String.split(s) |> Enum.map(&String.to_integer/1)
  end

  def parse_id(s) do
    ["Card", id_str] = String.split(s)
    String.to_integer(id_str)
  end

  def parse_card(s) do
    [id_str, card_str] = String.split(s, ":")
    [win_str, have_str] = String.split(card_str, "|")
    id = parse_id(id_str)
    winners = MapSet.new(parse_nums(win_str))
    haves = MapSet.new(parse_nums(have_str))
    {id, winners, haves}
  end

  def card_matches(winners, haves) do
    MapSet.intersection(winners, haves) |> MapSet.size()
  end

  def card_value(winners, haves) do
    matches = card_matches(winners, haves)
    if matches > 0 do Integer.pow(2, matches - 1) else 0 end
  end

  def parse_file(path) do
    File.stream!(path) |>
      Enum.map(&Scratch.parse_card/1) |>
      Enum.sort()
  end

  def incr_copies(ids, copies, count) do
    case ids do
      [] -> copies
      [id | rest] ->
	incr_copies(
	  rest,
	  Map.update(copies, id, count, fn prev -> prev + count end),
	  count)
    end
  end

  # N.B. requires cards to be sorted (in id order)
  def card_copies(cards, copies \\ %{}) do
    case cards do
      [card | rest] ->
	{id, winners, haves} = card
	copies = Map.update(copies, id, 1, fn prev -> prev + 1 end)
	matches = card_matches(winners, haves)
	if matches > 0 do
	  count = Map.get(copies, id, 0)
	  new_copies = incr_copies(
	    Enum.to_list((id + 1)..(id + matches)), copies, count)
	  card_copies(rest, new_copies)
	else
	  card_copies(rest, copies)
	end
      [] -> copies
    end
  end
end


### Part One.
# [path] = System.argv()
# total = File.stream!(path) |>
#   Stream.map(&Scratch.parse_card/1) |>
#   Stream.map(fn {_id, winners, haves} ->
#     Scratch.card_value(winners, haves) end) |>
#   Enum.sum
# IO.puts(total)
### End Part One.


### Part Two.
[path] = System.argv()
cards = Scratch.parse_file(path)
copies = Scratch.card_copies(cards)
# IO.inspect(copies)
count = Enum.reduce(copies, 0, fn({_id, num}, c) -> c + num end)
IO.puts(count)
### End Part Two.
