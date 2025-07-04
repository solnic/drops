defmodule Test.Extensions.ManualExtension do
  use Drops.Operations.Extension

  def extend(_source_module, _target_module, _opts) do
    quote do
    end
  end
end
