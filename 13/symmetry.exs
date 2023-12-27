defmodule Symmetry do
  def parse_line(s, images) do
    row = String.trim(s) |> to_charlist() |> Enum.map(fn v ->
      case v do
	?. -> ?.
	?# -> ?X
      end
    end)
    case images do
      [] ->
	if row == [] do [] else [[row]] end
      [img | rest] ->
	if row == [] do
	  [[], img | rest]
	else
	  [[row | img] | rest]
	end
    end
  end
  def parse_file(path) do
    File.stream!(path) |>
      Enum.reduce([], &parse_line/2) |>
      Enum.map(&Enum.reverse/1) |>
      Enum.reverse()
  end
  def equal_heads?(l1, l2) do
    case l1 do
      [] ->
	false
      [h1 | t1] ->
	case l2 do
	  [] -> false
	  [h2 | t2] ->
	    if h1 != h2 do
	      false
	    else
	      if t1 == [] or t2 == [] do
		true
	      else
		equal_heads?(t1, t2)
	      end
	    end
	end
    end
  end
  def head_diffs(rows1, rows2) do
    Enum.zip_reduce(rows1, rows2, 0, fn r1, r2, sum ->
      sum + Enum.zip_reduce(r1, r2, 0, fn i1, i2, s ->
	if i1 == i2 do s else s + 1 end
      end)
    end)
  end
  def nearly_sym_rows(below, rev_above \\ [], indices \\ []) do
    case below do
      [] ->
	Enum.reverse(indices)
      [row | rest] ->
	if head_diffs(below, rev_above) == 1 do
	  nearly_sym_rows(rest, [row | rev_above], [length(rev_above) | indices])
	else
	  nearly_sym_rows(rest, [row | rev_above], indices)
	end
    end
  end
  def nearly_sym_cols(image) do
    nearly_sym_rows(transpose(image))
  end
  def sym_rows(below, rev_above \\ [], indices \\ []) do
    case below do
      [] ->
	Enum.reverse(indices)
      [row | rest] ->
	if equal_heads?(below, rev_above) do
	  sym_rows(rest, [row | rev_above], [length(rev_above) | indices])
	else
	  sym_rows(rest, [row | rev_above], indices)
	end
    end
  end
  def transpose(image) do
    Enum.zip(image) |> Enum.map(&Tuple.to_list/1)
  end
  def sym_cols(image) do
    sym_rows(transpose(image))
  end
  def sym_sum(image) do
    100 * Enum.sum(sym_rows(image)) + Enum.sum(sym_cols(image))
  end
  def nearly_sym_sum(image) do
    100 * Enum.sum(nearly_sym_rows(image)) + Enum.sum(nearly_sym_cols(image))
  end
end


case System.argv() do
  ["1", path] ->
    Symmetry.parse_file(path) |>
      Enum.map(&Symmetry.sym_sum/1) |>
      Enum.sum() |>
      IO.inspect()
  ["2", path] ->
    Symmetry.parse_file(path) |>
      Enum.map(&Symmetry.nearly_sym_sum/1) |>
      Enum.sum() |>
      IO.inspect()
  _ ->
    :ok
end
