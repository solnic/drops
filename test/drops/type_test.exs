defmodule Drops.TypeTest do
  use Drops.ContractCase

  defmodule Email do
    use Drops.Type, string()
  end

  defmodule FilledEmail do
    use Drops.Type, string(:filled?)
  end

  doctest Drops.Type
end
