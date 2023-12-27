defmodule HailTest do
  use ExUnit.Case
  doctest Hail

  test "greets the world" do
    assert Hail.hello() == :world
  end
end
