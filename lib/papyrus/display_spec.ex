defmodule Papyrus.DisplaySpec do
  @moduledoc """
  Struct and behaviour describing a supported ePaper display model.

  Implement `@behaviour Papyrus.DisplaySpec` in a display module and
  provide a `spec/0` function that returns a populated `%DisplaySpec{}`.
  """

  @enforce_keys [:model, :width, :height, :buffer_size]
  defstruct [:model, :width, :height, :buffer_size, color_mode: :black_white]

  @type color_mode :: :black_white | :four_gray

  @type t :: %__MODULE__{
          model: atom(),
          width: pos_integer(),
          height: pos_integer(),
          buffer_size: pos_integer(),
          color_mode: color_mode()
        }

  @doc "Return the display specification struct."
  @callback spec() :: t()
end
