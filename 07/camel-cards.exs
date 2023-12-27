defmodule CamelCards do
  @card_rank %{
    ?2 => 2, ?3 => 3, ?4 => 4, ?5 => 5, ?6 => 6, ?7 => 7, ?8 => 8, ?9 => 9,
    ?T => 10, ?J => 11, ?Q => 12, ?K => 13, ?A => 14}
  @jcard_rank %{@card_rank | ?J => 1}
  @kind_rank %{
    high: 0, pair1: 1, pair2: 2, three: 3, full: 4, four: 5, five: 6}
  def parse_line(s) do
    [hand, bid_str] = String.split(s)
    cards = to_charlist(hand)
    bid = String.to_integer(bid_str)
    {cards, bid}
  end
  def kind(cards, joker_rule \\ false) do
    hand_map = Enum.reduce(cards, %{}, fn(card, hand) ->
      Map.update(hand, card, 1, fn count -> count + 1 end)
    end)
    {jokers, hand_map} = if joker_rule do
      Map.pop(hand_map, ?J, 0)
    else
      {0, hand_map}
    end
    counts = Map.values(hand_map) |> Enum.sort() |> Enum.reverse()
    counts = case counts do
	       [] ->
		 if jokers > 0 do [jokers] else [] end
	       [most | rest] ->
		 [most + jokers | rest]
	     end
    case counts do
      [5 | _] -> :five
      [4 | _] -> :four
      [3, 2 | _] -> :full
      [3 | _] -> :three
      [2, 2 | _] -> :pair2
      [2 | _] -> :pair1
      _ -> :high
    end
  end

  def winnings(hand_list, joker_rule \\ false) do
    Enum.map(hand_list, fn {cards, bid} ->
      {@kind_rank[kind(cards, joker_rule)],
       Enum.map(cards, fn c ->
	 if joker_rule do @jcard_rank[c] else @card_rank[c] end
       end),
       bid}
    end) |>
      Enum.sort() |>
      Enum.with_index(fn({_k, _c, bid}, index) ->
	(index + 1) * bid end) |>
      Enum.sum()
  end
end

case System.argv() do
  [stage, path] ->
    joker_rule = case stage do
		   "1" -> false
		   "2" -> true
		 end
    hand_list = File.stream!(path) |> Enum.map(&CamelCards.parse_line/1)
    IO.inspect(CamelCards.winnings(hand_list, joker_rule))
  _ ->
    :ok
end
