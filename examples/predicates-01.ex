Drops.Predicates.type?(:nil, nil)
Drops.Predicates.type?(:atom, :hello)
Drops.Predicates.type?(:string, "hello")
Drops.Predicates.type?(:integer, 1)
Drops.Predicates.type?(:float, 1.2)
Drops.Predicates.type?(:map, %{})
Drops.Predicates.type?(:date_time, DateTime.utc_now())
Drops.Predicates.filled?("hello")
Drops.Predicates.filled?("")
Drops.Predicates.filled?(["hello", "world"])
Drops.Predicates.filled?(%{hello: "world"})
Drops.Predicates.filled?(%{})
Drops.Predicates.empty?("hello")
Drops.Predicates.empty?("")
Drops.Predicates.empty?(["hello", "world"])
Drops.Predicates.empty?(%{hello: "world"})
Drops.Predicates.empty?(%{})
Drops.Predicates.eql?("hello", "hello")
Drops.Predicates.eql?("hello", "world")
Drops.Predicates.not_eql?("hello", "world")
Drops.Predicates.not_eql?("hello", "world")
Drops.Predicates.even?(4)
Drops.Predicates.even?(7)
Drops.Predicates.odd?(4)
Drops.Predicates.odd?(7)