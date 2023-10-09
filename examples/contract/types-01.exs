Drops.Types.from_spec({:type, {:string, []}}, [])

Drops.Types.from_spec({:type, {:string, [:filled?]}}, [])

Drops.Types.from_spec({:type, {:list, []}}, [])

Drops.Types.from_spec({:type, {:list, {:type, {:integer, []}}}}, [])

Drops.Types.from_spec([{:type, {:string, []}}, {:type, {:integer, []}}], [])

Drops.Types.from_spec({:type, {:map, []}}, [])

Drops.Types.from_spec(
  %{
    {:required, :name} => {:type, {:string, []}},
    {:optional, :age} => {:type, {:string, []}}
  },
  []
)

Drops.Types.from_spec(
  {:cast, {{:type, {:integer, []}}, {:type, {:date_time, []}}, [:miliseconds]}},
  []
)
