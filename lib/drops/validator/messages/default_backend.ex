defmodule Drops.Validator.Messages.DefaultBackend do
  @moduledoc false
  use Drops.Validator.Messages.Backend

  @text_mapping %{
    type?: %{
      nil: "must be nil",
      integer: "must be an integer",
      float: "must be a float",
      boolean: "must be boolean",
      list: "must be a list",
      map: "must be a map",
      string: "must be a string",
      atom: "must be an atom",
      date: "must be a date",
      date_time: "must be a date time",
      time: "must be a time"
    },
    has_key?: "key must be present",
    filled?: "must be filled",
    empty?: "must be empty",
    eql?: "must be equal to %input%",
    not_eql?: "must not be equal to %input%",
    lt?: "must be less than %input%",
    gt?: "must be greater than %input%",
    lteq?: "must be less than or equal to %input%",
    gteq?: "must be greater than or equal to %input%",
    min_size?: "size cannot be less than %input%",
    max_size?: "size cannot be greater than %input%",
    size?: "size must be %input%",
    even?: "must be even",
    odd?: "must be odd",
    match?: "must have a valid format",
    includes?: "must include %input%",
    excludes?: "must exclude %input%",
    in?: "must be one of: %input%",
    not_in?: "must not be one of: %input%",

    # built-in types
    number: "must be a number"
  }

  @impl true
  def text(:number, _opts) do
    @text_mapping[:number]
  end

  @impl true
  def text(predicate, _input) do
    @text_mapping[predicate]
  end

  @impl true
  def text(:type?, type, _input) do
    @text_mapping[:type?][type]
  end

  @impl true
  def text(:match?, _regex, _input) do
    @text_mapping[:match?]
  end

  @impl true
  def text(:in?, values, _input) do
    String.replace(@text_mapping[:in?], "%input%", Enum.join(values, ", "))
  end

  @impl true
  def text(:not_in?, values, _input) do
    String.replace(@text_mapping[:not_in?], "%input%", Enum.join(values, ", "))
  end

  @impl true
  def text(predicate, value, _input) do
    String.replace(@text_mapping[predicate], "%input%", to_string(value))
  end
end
