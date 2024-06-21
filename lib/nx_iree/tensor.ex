defmodule NxIREE.Tensor do
  @moduledoc """
  Thin wrapper that holds the device.

  Will be replaced by an Nx Backend implementation.
  """

  defstruct [:ref, :device]
end
