defmodule Drops.TypeTest do
  use Drops.ContractCase
  use Drops.DoctestCase

  defmodule Email do
    use Drops.Type, string()
  end

  defmodule FilledEmail do
    use Drops.Type, string(:filled?)
  end

  defmodule User do
    use Drops.Type, %{
      required(:name) => string(),
      required(:email) => string()
    }
  end

  defmodule Price do
    use Drops.Type, union([:integer, :float], gt?: 0)
  end

  doctest Drops.Type
end
