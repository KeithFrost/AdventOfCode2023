defmodule Oasis do
  def parse_seq(s) do
    String.split(s) |> Enum.map(&String.to_integer/1)
  end
  def parse_file(path) do
    File.stream!(path) |> Enum.map(&parse_seq/1)
  end
  def differences(seq) do
    Enum.chunk_every(seq, 2, 1, :discard) |>
      Enum.map(fn [a, b] -> b - a end)
  end
  def all_zero?(seq) do
    Enum.all?(seq, fn x -> x == 0 end)
  end
  def prediction(seq, backwards \\ false) do
    diffns = Stream.unfold(seq, fn x ->
      if all_zero?(x) do
        nil
      else
        {x, differences(x)}
      end
    end) |>
      Enum.reverse()
    if backwards do
      Enum.reduce(diffns, 0, fn(seq, d) -> List.first(seq) - d end)
    else
      Enum.reduce(diffns, 0, fn(seq, d) -> List.last(seq) + d end)
    end
  end
end

case System.argv() do
  [stage, path] ->
    backwards = case stage do
                  "1" -> false
                  "2" -> true
                end
    seqs = Oasis.parse_file(path)
    Enum.map(seqs, fn seq -> Oasis.prediction(seq, backwards) end) |>
      Enum.sum() |>
      IO.inspect()

  _ ->
    :ok
end
