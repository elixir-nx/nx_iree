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
    # tensor/2 tests on f8 which is not supported yet
    tensor: 2,
    # iota/2 tests on f64 which is not supported on metal
    iota: 2
  ]

  @errors_to_be_fixed [
    to_batched: 3,
    top_k: 2,
    window_product: 3,
    window_mean: 3,
    window_sum: 3,
    window_min: 3,
    window_max: 3,
    sort: 2,
    argsort: 2,
    argmax: 2,
    argmin: 2,
    conv: 3,
    all_close: 3,
    is_nan: 1,
    population_count: 1,
    count_leading_zeros: 1,
    mode: 2,
    # Median has a halting bug
    median: 2,
    take: 3
  ]

  doctest Nx,
    except: @illegal_ops ++ @rounding_error ++ @partial_support ++ @errors_to_be_fixed
end
