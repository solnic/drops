defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      required(:name) => string(),
      required(:age) => integer(),
      required(:active) => boolean(),
      required(:tags) => list(string()),
      required(:settings) => map(:string),
      required(:address) => maybe(:string)
    }
  end
end
