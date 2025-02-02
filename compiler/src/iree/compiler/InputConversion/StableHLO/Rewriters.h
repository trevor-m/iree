// Copyright 2019 The IREE Authors
//
// Licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

#ifndef IREE_COMPILER_INPUTCONVERSION_STABLEHLO_REWRITERS_H_
#define IREE_COMPILER_INPUTCONVERSION_STABLEHLO_REWRITERS_H_

#include "mlir/Transforms/DialectConversion.h"

namespace mlir::iree_compiler::stablehlo {

/// Populates the patterns that convert from StableHLO to Linalg on tensors.
void populateStableHloToLinalgConversionPatterns(MLIRContext* context,
                                                 TypeConverter& typeConverter,
                                                 RewritePatternSet* patterns,
                                                 bool enablePrimitiveOps);

//===----------------------------------------------------------------------===//
// Fine-grained patterns used by the implementation.
//===----------------------------------------------------------------------===//
namespace detail {
/// Populates the patterns that convert from elementwise StableHLO ops to Linalg
/// on tensors.
void populatePointwiseStableHloToLinalgConversionPatterns(
    MLIRContext* context, TypeConverter& typeConverter,
    RewritePatternSet* patterns, bool enablePrimitiveOps);

/// Populates the patterns that convert from dot product StableHLO ops to Linalg
/// on tensors.
void populateStableHloDotProdToLinalgConversionPatterns(
    MLIRContext* context, TypeConverter& typeConverter,
    RewritePatternSet* patterns);

/// Populates the patterns that convert scalar StableHLO ops to Arith ops.
void populateScalarHloToArithConversionPatterns(
    MLIRContext* context, TypeConverter& typeConverter,
    RewritePatternSet* patterns,
    llvm::function_ref<bool(Operation*)> filterFn = nullptr);
}  // namespace detail

}  // namespace mlir::iree_compiler::stablehlo

#endif  // IREE_COMPILER_INPUTCONVERSION_STABLEHLO_REWRITERS_H_
