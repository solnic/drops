defmodule Drops.CastersTest do
  use Drops.ContractCase

  doctest Drops.Casters

  describe ":integer => :string" do
    contract do
      schema do
        %{required(:test) => cast(:integer) |> string()}
      end
    end

    test "defining a required key with coercion", %{contract: contract} do
      assert {:ok, %{test: "12"}} = contract.conform(%{test: 12})
    end
  end

  describe ":integer => :string with constraints" do
    contract do
      schema do
        %{required(:test) => cast(:integer) |> string(size?: 3)}
      end
    end

    test "returns successful result when input is valid", %{contract: contract} do
      assert {:ok, %{test: "312"}} = contract.conform(%{test: 312})
    end

    test "returns error result when output is invalid", %{contract: contract} do
      assert {:error, [error: {[:test], :size?, [3, "12"]}]} =
               contract.conform(%{test: 12})
    end

    test "returns error when casting could not be applied", %{contract: contract} do
      assert {:error, [error: {:cast, {:error, {[:test], :type?, [:integer, "12"]}}}]} =
               contract.conform(%{test: "12"})
    end
  end

  describe ":string => :integer" do
    contract do
      schema do
        %{required(:test) => cast(:string) |> integer()}
      end
    end

    test "defining a required key with coercion", %{contract: contract} do
      assert {:ok, %{test: 12}} = contract.conform(%{test: "12"})
    end
  end

  describe ":string => :float" do
    contract do
      schema do
        %{required(:test) => cast(:string) |> type(:float)}
      end
    end

    test "defining a required key with coercion", %{contract: contract} do
      assert {:ok, %{test: 31.2}} = contract.conform(%{test: "31.2"})
    end
  end

  describe ":integer => :date_time" do
    contract do
      schema do
        %{required(:test) => cast(:integer) |> type(:date_time)}
      end
    end

    test "defining a required key with coercion", %{contract: contract} do
      timestamp = 1_695_277_470
      date_time = DateTime.from_unix!(timestamp, :second)

      assert {:ok, %{test: ^date_time}} = contract.conform(%{test: timestamp})
    end
  end

  describe ":integer => :date_time with :milliseconds" do
    contract do
      schema do
        %{required(:test) => cast(:integer, [:millisecond]) |> type(:date_time)}
      end
    end

    test "defining a required key with coercion", %{contract: contract} do
      timestamp = 1_695_277_723_355
      date_time = DateTime.from_unix!(timestamp, :millisecond)

      assert {:ok, %{test: ^date_time}} = contract.conform(%{test: timestamp})
    end
  end

  describe "using a customer caster" do
    contract do
      defmodule CustomCaster do
        def cast(:string, :string, value, _opts) do
          String.downcase(value)
        end
      end

      schema do
        %{required(:test) => cast(:string, caster: CustomCaster) |> type(:string)}
      end
    end

    test "defining a required key with coercion", %{contract: contract} do
      assert {:ok, %{test: "hello"}} = contract.conform(%{test: "HELLO"})
    end
  end
end
