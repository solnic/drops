defmodule Drops.PredicatesTest do
  use Drops.ContractCase

  describe "type?/2 with :atom" do
    contract do
      schema do
        %{required(:test) => type(:atom)}
      end
    end

    test "returns success with a string value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: :hello})
    end

    test "returns error with a non-string value", %{contract: contract} do
      assert {:error, [{:error, {:atom?, [:test], 312}}]} =
               contract.conform(%{test: 312})
    end
  end

  describe "type?/2 with :string" do
    contract do
      schema do
        %{required(:test) => type(:string)}
      end
    end

    test "returns success with a string value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: "Hello"})
    end

    test "returns error with a non-string value", %{contract: contract} do
      assert {:error, [{:error, {:string?, [:test], 312}}]} =
               contract.conform(%{test: 312})
    end
  end

  describe "type?/2 with :integer" do
    contract do
      schema do
        %{required(:test) => type(:integer)}
      end
    end

    test "returns success with an integer value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: 312})
    end

    test "returns error with a non-integer value", %{contract: contract} do
      assert {:error, [{:error, {:integer?, [:test], "Hello"}}]} =
               contract.conform(%{test: "Hello"})
    end
  end

  describe "type?/2 with :float" do
    contract do
      schema do
        %{required(:test) => type(:float)}
      end
    end

    test "returns success with an integer value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: 31.2})
    end

    test "returns error with a non-integer value", %{contract: contract} do
      assert {:error, [{:error, {:float?, [:test], 312}}]} =
               contract.conform(%{test: 312})
    end
  end

  describe "type?/2 with :map" do
    contract do
      schema do
        %{required(:test) => type(:map)}
      end
    end

    test "returns success with a map value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: %{}})
    end

    test "returns error with a non-map value", %{contract: contract} do
      assert {:error, [{:error, {:map?, [:test], 312}}]} = contract.conform(%{test: 312})
    end
  end

  describe "type?/2 with :date" do
    contract do
      schema do
        %{required(:test) => type(:date)}
      end
    end

    test "returns success with a string value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: ~D[2023-09-12]})
    end

    test "returns error with a non-string value", %{contract: contract} do
      assert {:error, [{:error, {:date?, [:test], 312}}]} =
               contract.conform(%{test: 312})
    end
  end

  describe "type?/2 with :date_time" do
    contract do
      schema do
        %{required(:test) => type(:date_time)}
      end
    end

    test "returns success with a string value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: DateTime.utc_now()})
    end

    test "returns error with a non-string value", %{contract: contract} do
      assert {:error, [{:error, {:date_time?, [:test], 312}}]} =
               contract.conform(%{test: 312})
    end
  end

  describe "type?/2 with :time" do
    contract do
      schema do
        %{required(:test) => type(:time)}
      end
    end

    test "returns success with a string value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: Time.utc_now()})
    end

    test "returns error with a non-string value", %{contract: contract} do
      assert {:error, [{:error, {:time?, [:test], 312}}]} =
               contract.conform(%{test: 312})
    end
  end

  describe "type?/2 with :list" do
    contract do
      schema do
        %{required(:test) => type(:list)}
      end
    end

    test "returns success with a string value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: [1, 2, 3]})
    end

    test "returns error with a non-string value", %{contract: contract} do
      assert {:error, [{:error, {:list?, [:test], 312}}]} =
               contract.conform(%{test: 312})
    end
  end

  describe "filled?/1" do
    contract do
      schema do
        %{required(:test) => type(:string, [:filled?])}
      end
    end

    test "returns success with a non-empty string", %{contract: contract} do
      assert {:ok, %{test: "Hello"}} = contract.conform(%{test: "Hello"})
    end

    test "returns error with an empty string", %{contract: contract} do
      assert {:error, [{:error, {:filled?, [:test], ""}}]} = contract.conform(%{test: ""})
    end
  end

  describe "empty?/1 with :string" do
    contract do
      schema do
        %{required(:test) => type(:string, [:empty?])}
      end
    end

    test "returns success with an empty string", %{contract: contract} do
      assert {:ok, %{test: ""}} = contract.conform(%{test: ""})
    end

    test "returns error with a non-empty string", %{contract: contract} do
      assert {:error, [{:error, {:empty?, [:test], "Hello"}}]} =
               contract.conform(%{test: "Hello"})
    end
  end

  describe "empty?/1 with :list" do
    contract do
      schema do
        %{required(:test) => type(:list, [:empty?])}
      end
    end

    test "returns success with an empty list", %{contract: contract} do
      assert {:ok, %{test: []}} = contract.conform(%{test: []})
    end

    test "returns error with a non-empty list", %{contract: contract} do
      assert {:error, [{:error, {:empty?, [:test], [1, 2]}}]} =
               contract.conform(%{test: [1, 2]})
    end
  end

  describe "empty?/1 with :map" do
    contract do
      schema do
        %{required(:test) => type(:map, [:empty?])}
      end
    end

    test "returns success with an empty map", %{contract: contract} do
      assert {:ok, %{test: %{}}} = contract.conform(%{test: %{}})
    end

    test "returns error with a non-empty map", %{contract: contract} do
      assert {:error, [{:error, {:empty?, [:test], %{a: 1}}}]} =
               contract.conform(%{test: %{a: 1}})
    end
  end

  describe "eql?/1" do
    contract do
      schema do
        %{required(:test) => type(:string, [eql?: "Hello"])}
      end
    end

    test "returns success when the value is equal", %{contract: contract} do
      assert {:ok, %{test: "Hello"}} = contract.conform(%{test: "Hello"})
    end

    test "returns error when the value is not equal", %{contract: contract} do
      assert {:error, [{:error, {:eql?, [:test], ["Hello", "World"]}}]} =
               contract.conform(%{test: "World"})
    end
  end

  describe "not_eql?/1" do
    contract do
      schema do
        %{required(:test) => type(:string, [not_eql?: "Hello"])}
      end
    end

    test "returns success when the value is not equal", %{contract: contract} do
      assert {:ok, %{test: "World"}} = contract.conform(%{test: "World"})
    end

    test "returns error when the value is equal", %{contract: contract} do
      assert {:error, [{:error, {:not_eql?, [:test], ["Hello", "Hello"]}}]} =
               contract.conform(%{test: "Hello"})
    end
  end
end
