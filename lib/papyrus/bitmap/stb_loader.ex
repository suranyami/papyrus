defmodule Papyrus.Bitmap.StbLoader do
  @moduledoc "Default image loader using stb_image. Loads images as single-channel grayscale."

  @behaviour Papyrus.Bitmap.Loader

  @impl true
  def load(path) do
    case StbImage.read_file(path, channels: 1) do
      {:ok, img} -> {:ok, img}
      {:error, reason} -> {:error, reason}
    end
  end
end
