// Copyright 2023 The IREE Authors
//
// Licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

#ifndef IREE_BUILTINS_UKERNEL_ARCH_X86_64_UNPACK_X86_64_INTERNAL_H_
#define IREE_BUILTINS_UKERNEL_ARCH_X86_64_UNPACK_X86_64_INTERNAL_H_

#include "iree/builtins/ukernel/unpack_internal.h"

IREE_UK_UNPACK_TILE_FUNC_DECL(
    iree_uk_unpack_tile_8x8_x32_x86_64_avx2_fma_direct)
IREE_UK_UNPACK_TILE_FUNC_DECL(
    iree_uk_unpack_tile_16x16_x32_x86_64_avx512_base_direct)

#endif  // IREE_BUILTINS_UKERNEL_ARCH_X86_64_UNPACK_X86_64_INTERNAL_H_
