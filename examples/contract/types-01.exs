Drops.Type.Compiler.visit({:type, {:string, []}}, [])

Drops.Type.Compiler.visit({:type, {:string, [:filled?]}}, [])

Drops.Type.Compiler.visit({:type, {:list, []}}, [])

Drops.Type.Compiler.visit({:type, {:list, {:type, {:integer, []}}}}, [])

Drops.Type.Compiler.visit([{:type, {:string, []}}, {:type, {:integer, []}}], [])

Drops.Type.Compiler.visit({:type, {:map, []}}, [])

Drops.Type.Compiler.visit(
  %{
    {:required, :name} => {:type, {:string, []}},
    {:optional, :age} => {:type, {:string, []}}
  },
  []
)

Drops.Type.Compiler.visit(
  {:cast, {{:type, {:integer, []}}, {:type, {:date_time, []}}, [:miliseconds]}},
  []
)
