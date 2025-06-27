defmodule Drops.TestRepo do
  @moduledoc """
  Test repository for Ecto operations in test environment.
  
  This repo is configured to use SQLite in-memory database for testing.
  """
  
  use Ecto.Repo,
    otp_app: :drops,
    adapter: Ecto.Adapters.SQLite3
end
