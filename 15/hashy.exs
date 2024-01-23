defmodule Hashy do
  use Bitwise
  def hashc(s) do
    to_charlist(s) |>
      Enum.reduce(0, fn c, v -> ((v + c) * 17) &&& 255 end)
  end
  def parse_line(s) do
    String.split(s, ",") |> Enum.map(&String.trim/1)
  end
  def parse_file(path) do
    File.stream!(path) |> Enum.flat_map(&parse_line/1)
  end
  def parse_setting(s) do
    [_, label, ops, digits] = Regex.run(~r/^(\w+)(-|=)(\d*)$/, s)
    op = List.first(to_charlist(ops))
    case op do
      ?- -> {label, op, 0}
      ?= -> {label, op, String.to_integer(digits)}
    end
  end
  def replace_or_append({label, focus}, lenses, acc \\ []) do
    case lenses do
      [] ->
        Enum.reverse([{label, focus} | acc])
      [{l, f} | rest] ->
        if label == l do
          Enum.reverse(acc, [{label, focus} | rest])
        else
          replace_or_append({label, focus}, rest, [{l, f} | acc])
        end
    end
  end
  def perform_setting({label, op, focus}, state) do
    box = hashc(label)
    lenses = Map.get(state, box, [])
    new_lenses =
      case op do
        ?= ->
          replace_or_append({label, focus}, lenses)
        ?- ->
          Enum.filter(lenses, fn {l, _f} -> l != label end)
      end
    Map.put(state, box, new_lenses)
  end
  def total_focus_power(state) do
    Enum.reduce(state, 0, fn {box, lenses}, sum ->
      lens_sum =
        Enum.with_index(lenses, fn {_label, focus}, i ->
          (1 + i) * focus
        end) |> Enum.sum()
      sum + (box + 1) * lens_sum
    end)
  end
end


case System.argv() do
  ["1", path] ->
    Hashy.parse_file(path) |>
      Enum.reduce(0, fn s, sum -> sum + Hashy.hashc(s) end) |>
      IO.inspect()
  ["2", path] ->
    state = Hashy.parse_file(path) |>
      Enum.reduce(%{}, fn ss, state ->
        setting = Hashy.parse_setting(ss)
        Hashy.perform_setting(setting, state)
      end)
    IO.inspect(Hashy.total_focus_power(state))
  [] ->
    :ok
end
