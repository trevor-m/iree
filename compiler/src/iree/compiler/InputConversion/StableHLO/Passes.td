// Copyright 2019 The IREE Authors
//
// Licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

#ifndef IREE_COMPILER_INPUTCONVERSION_STABLEHLO_PASSES
#define IREE_COMPILER_INPUTCONVERSION_STABLEHLO_PASSES

include "mlir/Pass/PassBase.td"

def ConvertStableHloToLinalg :
    Pass<"iree-stablehlo-to-linalg", "ModuleOp"> {
  let summary = "Convert from StableHLO ops to Linalg ops on tensors";
  let options = [Option<"enablePrimitiveOps", "enable-primitive-ops", "bool",
                        /*default=*/"false",
                        "Lower to primitive Linalg ops (map, reduce and "
                        "transpose) when possible, instead of linalg.generic">];
}

#endif // IREE_COMPILER_INPUTCONVERSION_STABLEHLO_PASSES
