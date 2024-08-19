defmodule NxIREE.NativeTest do
  use ExUnit.Case, async: true

  test "serializes and deserializes a tensor" do
    tensor = Nx.tensor([[[1, 2], [3, 4], [5, 6]]], type: :s32, backend: NxIREE.Tensor)

    {:ok, serialized} = NxIREE.Native.serialize_tensor(tensor.data.ref)

    assert <<
             type::unsigned-integer-native-size(32),
             num_bytes::unsigned-integer-native-size(64),
             data::binary-size(num_bytes),
             num_dims::unsigned-integer-native-size(64),
             dims_bin::bitstring
           >> = serialized

    dims =
      for <<x::signed-integer-native-size(64) <- dims_bin>> do
        x
      end

    # the type assertion is really an internal type to iree,
    # but we assert on it as a sanity check.
    # This can be skipped if needed in the future.
    assert Bitwise.band(type, 0xFF) == 32
    assert Bitwise.band(Bitwise.bsr(type, 24), 0xFF) == 0x10

    assert num_bytes == Nx.byte_size(tensor)
    assert data == Nx.to_binary(tensor)
    assert num_dims == 3
    assert dims == [1, 3, 2]

    {:ok, deserialized_ref} = NxIREE.Native.deserialize_tensor(serialized)

    assert Nx.to_binary(tensor) == Nx.to_binary(put_in(tensor.data.ref, deserialized_ref))
  end
end
