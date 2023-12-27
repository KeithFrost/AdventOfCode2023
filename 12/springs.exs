defmodule Springs do
  def parse_line(s, copies \\ 1) do
    [springs_str, lens_str] = String.split(s)
    springs_str = Enum.join(List.duplicate(springs_str, copies), "?")
    lens_str = Enum.join(List.duplicate(lens_str, copies), ",")
    springs = to_charlist(springs_str) |> Enum.map(fn
      ?# -> ?B
      ?. -> ?.
      ?? -> ?U
    end)
    lens = String.split(lens_str, ",") |> Enum.map(&String.to_integer/1)
    {springs, lens}
  end
  def all_springs(springs, lens, prevs \\ []) do
    case springs do
      [] ->
	if lens == [] do
	  [Enum.reverse(prevs)]
	else
	  []
	end
      [?. | rest] ->
	all_springs(rest, lens, [?. | prevs])
      [?B | rest] ->
	if lens == [] do
	  []
	else
	  [len | rlens] = lens
	  if (length(rest) < len - 1) do
	    []
	  else
	    {to_bs, rrest} = Enum.split(rest, len - 1)
	    if Enum.any?(to_bs, fn v -> v == ?. end) do
	      []
	    else
	      group = List.duplicate(?B, len)
	      case rrest do
		[] ->
		  all_springs([], rlens, group ++ prevs)
		[?. | rrest2] ->
		  all_springs(rrest2, rlens, [?. | group] ++ prevs)
		[?U | rrest2] ->
		  all_springs(rrest2, rlens, [?. | group] ++ prevs)
		[?B | _] ->
		  []
	      end
	    end
	  end
	end
      [?U | rest] ->
	if lens == [] do
	  all_springs(rest, [], [?. | prevs])
	else
	  all_springs([?B | rest], lens, prevs) ++
	    all_springs(rest, lens, [?. | prevs])
	end
    end
  end
  def count_solutions(springs, lens, cache \\ %{}) do
    count = Map.get(cache, {springs, lens})
    if count != nil do
      {count, cache}
    else
      case springs do
	[] ->
	  if lens == [] do {1, cache} else {0, cache} end
	[?. | rest] ->
	  count_solutions(rest, lens, cache)
	[?B | rest] ->
	  if lens == [] do
	    {0, cache}
	  else
	    [len | rlens] = lens
	    if (length(rest) < len - 1) do
	      {0, cache}
	    else
	      {to_bs, rrest} = Enum.split(rest, len - 1)
	      if Enum.any?(to_bs, fn v -> v == ?. end) do
		{0, cache}
	      else
		case rrest do
		  [] ->
		    if rlens == [] do {1, cache} else {0, cache} end
		  [?. | rrest2] ->
		    count_solutions(rrest2, rlens, cache)
		  [?U | rrest2] ->
		    count_solutions(rrest2, rlens, cache)
		  [?B | _] ->
		    {0, cache}
		end
	      end
	    end
	  end
	[?U | rest] ->
	  if lens == [] do
	    count_solutions(rest, [], cache)
	  else
	    {countb, cache} = count_solutions([?B | rest], lens, cache)
	    {countk, cache} = count_solutions(rest, lens, cache)
	    count = countb + countk
	    {count, Map.put(cache, {springs, lens}, count)}
	  end
      end
    end
  end
end

case System.argv() do
  [stage, path] ->
    copies = case stage do
	       "1" -> 1
	       "2" -> 5
	     end
    {sum, _} = File.stream!(path) |>
      Enum.reduce({0, %{}}, fn line, {sum, cache} ->
	{springs, groups} = Springs.parse_line(line, copies)
	{count, ncache} = Springs.count_solutions(springs, groups, cache)
	{sum + count, ncache}
      end)
    IO.inspect(sum)
  [] ->
    :ok
end
