defmodule Papyrus do
  @moduledoc """
  Public API for driving ePaper displays via a supervised OS port process.

  Each display is managed by a `Papyrus.Display` GenServer that owns a
  port to the `priv/epd_port` C binary. Display updates (which can take
  1–30 seconds) run synchronously in the GenServer — callers block until
  the hardware confirms completion.

  ## Quick start

      {:ok, display} = Papyrus.start_display(display_module: Papyrus.Displays.Waveshare12in48)
      :ok = Papyrus.clear(display)
      :ok = Papyrus.display(display, image_buffer)
      :ok = Papyrus.sleep(display)
  """

  @doc "Start a display GenServer. See `Papyrus.Display.start_link/1` for options."
  defdelegate start_display(opts), to: Papyrus.Display, as: :start_link

  @doc "Send a full-frame image buffer to the display."
  defdelegate display(server, image), to: Papyrus.Display

  @doc "Clear the display to white."
  defdelegate clear(server), to: Papyrus.Display

  @doc "Put the display hardware into deep sleep mode."
  defdelegate sleep(server), to: Papyrus.Display

  @doc "Return the `%Papyrus.DisplaySpec{}` for the connected display."
  defdelegate spec(server), to: Papyrus.Display
end
