defmodule Papyrus.DisplaySpec do
  @moduledoc """
  Struct and behaviour describing a supported ePaper display model.

  Implement `@behaviour Papyrus.DisplaySpec` in a display module and
  provide a `spec/0` function that returns a populated `%DisplaySpec{}`.

  ## Fields

  - `:model` — atom identifying the display model (e.g. `:waveshare_12in48`). Required.
  - `:width` — display width in pixels. Required.
  - `:height` — display height in pixels. Required.
  - `:buffer_size` — size in bytes of the packed pixel buffer the C port expects. Required.
  - `:pin_config` — flat atom-keyed map of GPIO pin numbers. Keys mirror `DEV_Config.h`
    naming conventions for readability when debugging. Required. Example for a simple
    single-panel display: `%{rst: 6, dc: 13, cs: 8, busy: 5}`. For multi-panel displays
    (e.g. Waveshare 12.48") use namespaced keys: `%{m1_cs: 8, s1_cs: 7, ...}`.
  - `:bit_order` — pixel polarity for white. `:white_high` means `0xFF` = white (most common);
    `:white_low` means `0x00` = white. Required. See `t:bit_order/0`.
  - `:color_mode` — describes the display's color capability. Defaults to `:black_white`.
    See `t:color_mode/0` for supported values.
  - `:partial_refresh` — boolean indicating whether the display hardware supports partial
    refresh (updating a sub-region without a full refresh cycle). Defaults to `false`.
  """

  @enforce_keys [:model, :width, :height, :buffer_size, :pin_config, :bit_order]
  defstruct [
    :model,
    :width,
    :height,
    :buffer_size,
    :pin_config,
    :bit_order,
    color_mode: :black_white,
    partial_refresh: false
  ]

  @typedoc """
  A flat atom-keyed map of GPIO pin numbers.

  Keys should mirror the naming conventions in the display's `DEV_Config.h` file.
  Values are non-negative integers representing BCM GPIO pin numbers.
  """
  @type pin_config :: %{required(atom()) => non_neg_integer()}

  @typedoc """
  Bit polarity convention for white pixels.

  - `:white_high` — `0xFF` encodes white (most common; used by Waveshare B&W and 3-color panels)
  - `:white_low` — `0x00` encodes white (used by some alternative display controllers)
  """
  @type bit_order :: :white_high | :white_low

  @typedoc """
  Color capability of the display.

  - `:black_white` — standard 1-bit black-and-white display
  - `:three_color` — 3-color display (black, white, and red or yellow accent layer)
  - `:four_gray` — 4-level grayscale display (2 bits per pixel)
  """
  @type color_mode :: :black_white | :three_color | :four_gray

  @type t :: %__MODULE__{
          model: atom(),
          width: pos_integer(),
          height: pos_integer(),
          buffer_size: pos_integer(),
          pin_config: pin_config(),
          bit_order: bit_order(),
          color_mode: color_mode(),
          partial_refresh: boolean()
        }

  @doc "Return the display specification struct."
  @callback spec() :: t()
end
