defmodule NxIREE.NxTest do
  use ExUnit.Case

  @illegal_ops [
    fft: 2,
    fft2: 2,
    ifft: 2,
    ifft2: 2,
    select_and_scatter: 3,
    window_scatter_min: 5,
    window_scatter_max: 5
  ]

  @rounding_error [
    erf: 1,
    erfc: 1,
    asinh: 1,
    cbrt: 1,
    atan2: 2,
    cosh: 1,
    expm1: 1,
    sigmoid: 1,
    standard_deviation: 2,
    atanh: 1,
    tanh: 1,
    tan: 1,
    real: 1,
    asin: 1,
    asinh: 1,
    atan: 1,
    acos: 1,
    acosh: 1,
    cos: 1,
    sin: 1,
    phase: 1,
    covariance: 3,
    weighted_mean: 3,
    variance: 2,
    # as_type tests on f64 which is not supported on metal
    as_type: 2,
    rsqrt: 1
  ]

  @partial_support [
    # stable: true is not supported
    argsort: 2,
    # tensor/2 tests on f8 which is not supported yet
    tensor: 2,
    # bit_size/1 tests on u2 which is not supported yet
    bit_size: 1,
    # iota/2 tests on f64 which is not supported on metal
    iota: 2,
    # does not support complex tensors
    conv: 3
  ]

  @errors_to_be_fixed [
    # bug on filter_by_indices_list in the Nx compiler
    top_k: 2,
    # window_* crashes on iree-compile
    window_product: 3,
    window_mean: 3,
    window_sum: 3,
    window_min: 3,
    window_max: 3
  ]

  doctest Nx,
    except:
      @illegal_ops ++
        @rounding_error ++ @partial_support ++ @errors_to_be_fixed
end
