defprotocol Drops.Type.Validator do
  @moduledoc ~S"""
  Protocol for validating input using types
  """

  @spec validate(struct(), any(), Keyword.t()) :: {:ok, any()} | {:error, any()}
  def validate(type, value, opts)
end
