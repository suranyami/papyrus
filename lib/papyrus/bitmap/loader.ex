defmodule Papyrus.Bitmap.Loader do
  @moduledoc "Behaviour for image loading backends."

  @callback load(path :: String.t()) :: {:ok, StbImage.t()} | {:error, atom()}
end
