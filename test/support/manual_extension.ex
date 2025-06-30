defmodule Test.Support.ManualExtension do
  @behaviour Drops.Operations.Extension

  @impl true
  def enabled?(_opts) do
    false
  end

  @impl true
  def extend_operation(_opts) do
    []
  end
end
