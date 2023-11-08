defprotocol Drops.Type.Validator do
  @moduledoc ~S"""
  Protocol for validating input using types
  """

  @spec validate(struct(), any()) :: {:ok, any()} | {:error, {any(), keyword()}}
  def validate(type, value)
end
