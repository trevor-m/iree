// RUN: iree-opt -split-input-file -pass-pipeline="builtin.func(iree-stream-schedule-execution)" %s | IreeFileCheck %s

// Tests basic partitioning of multiple ops.

// CHECK-LABEL: @partitioning
// CHECK-SAME: (%[[ARG0:.+]]: !stream.resource<external>, %[[ARG1:.+]]: !stream.resource<external>)
func @partitioning(%arg0: !stream.resource<external>, %arg1: !stream.resource<external>) -> !stream.resource<external> {
  %c1 = arith.constant 1 : index
  %c20 = arith.constant 20 : index
  %c80 = arith.constant 80 : index
  %c1280 = arith.constant 1280 : index
  %cst = arith.constant 0x7F800000 : f32
  // CHECK: %[[RESULT:.+]], %[[TIMEPOINT:.+]] = stream.async.execute
  // CHECK-SAME: with(%[[ARG1]] as %[[ARG1_CAPTURE:.+]]: !stream.resource<external>{%c80},
  // CHECK-SAME:      %[[ARG0]] as %[[ARG0_CAPTURE:.+]]: !stream.resource<external>{%c20})
  // CHECK-SAME: -> !stream.resource<external>{%c20} {
  // CHECK-NEXT: %[[SPLAT0:.+]] = stream.async.splat
  %2 = stream.async.splat %cst : f32 -> !stream.resource<transient>{%c1280}
  // CHECK-NEXT: %[[DISPATCH0:.+]] = stream.async.dispatch @ex::@dispatch_0[%c1, %c1, %c1](%[[SPLAT0]], %[[ARG1_CAPTURE]]) : (!stream.resource<transient>{%c1280}, !stream.resource<external>{%c80}) -> %[[SPLAT0]]{%c1280}
  %3 = stream.async.dispatch @ex::@dispatch_0[%c1, %c1, %c1](%2, %arg1) : (!stream.resource<transient>{%c1280}, !stream.resource<external>{%c80}) -> %2{%c1280}
  // CHECK-NEXT: %[[SPLAT1:.+]] = stream.async.splat
  %4 = stream.async.splat %cst : f32 -> !stream.resource<transient>{%c20}
  // CHECK-NEXT: %[[DISPATCH1:.+]] = stream.async.dispatch @ex::@dispatch_1[%c1, %c1, %c1](%[[ARG0_CAPTURE]], %[[SPLAT1]]) : (!stream.resource<external>{%c20}, !stream.resource<transient>{%c20}) -> %[[SPLAT1]]{%c20}
  %5 = stream.async.dispatch @ex::@dispatch_1[%c1, %c1, %c1](%arg0, %4) : (!stream.resource<external>{%c20}, !stream.resource<transient>{%c20}) -> %4{%c20}
  // CHECK-NEXT: %[[DISPATCH2:.+]] = stream.async.dispatch @ex::@dispatch_2[%c1, %c1, %c1](%[[DISPATCH0]], %[[DISPATCH1]]) : (!stream.resource<transient>{%c1280}, !stream.resource<transient>{%c20}) -> !stream.resource<external>{%c20}
  %6 = stream.async.dispatch @ex::@dispatch_2[%c1, %c1, %c1](%3, %5) : (!stream.resource<transient>{%c1280}, !stream.resource<transient>{%c20}) -> !stream.resource<external>{%c20}
  // CHECK-NEXT: stream.yield %[[DISPATCH2]] : !stream.resource<external>{%c20}
  // CHECK-NEXT: } => !stream.timepoint
  // CHECK-NEXT: %[[READY:.+]] = stream.timepoint.await %[[TIMEPOINT]] => %[[RESULT]] : !stream.resource<external>{%c20}
  // CHECK-NEXT: return %[[READY]]
  return %6 : !stream.resource<external>
}

// -----

// Tests that ops in multiple blocks are partitioned independently and that
// timepoints are chained between the partitions. Note that the dispatches
// happen in-place on the splat and we expect the execution regions to be tied.

// CHECK-LABEL: @partitionWithinBlocks
func @partitionWithinBlocks(%cond: i1) -> !stream.resource<transient> {
  %c1 = arith.constant 1 : index
  %c1280 = arith.constant 1280 : index
  %cst = arith.constant 0x7F800000 : f32
  // CHECK: %[[SPLAT:.+]], %[[SPLAT_TIMEPOINT:.+]] = stream.async.execute
  // CHECK: stream.async.splat
  %splat = stream.async.splat %cst : f32 -> !stream.resource<transient>{%c1280}
  // CHECK: cond_br
  cond_br %cond, ^bb1, ^bb2
^bb1:
  // CHECK: %[[BB1_RESULT:.+]], %[[BB1_TIMEPOINT:.+]] = stream.async.execute await(%[[SPLAT_TIMEPOINT]]) =>
  // CHECK-SAME: with(%[[SPLAT]] as %[[BB1_SPLAT:.+]]: !stream.resource<transient>{%c1280})
  // CHECK-SAME: -> %[[SPLAT]]{%c1280}
  // CHECK: stream.async.dispatch @ex::@dispatch_0[%c1, %c1, %c1](%[[BB1_SPLAT]]) : (!stream.resource<transient>{%c1280}) -> %[[BB1_SPLAT]]{%c1280}
  %3 = stream.async.dispatch @ex::@dispatch_0[%c1, %c1, %c1](%splat) : (!stream.resource<transient>{%c1280}) -> %splat{%c1280}
  // CHECK: %[[BB1_READY:.+]] = stream.timepoint.await %[[BB1_TIMEPOINT]] => %[[BB1_RESULT]]
  // CHECK: return %[[BB1_READY]]
  return %3 : !stream.resource<transient>
^bb2:
  // CHECK: %[[BB2_RESULT:.+]], %[[BB2_TIMEPOINT:.+]] = stream.async.execute await(%[[SPLAT_TIMEPOINT]]) =>
  // CHECK-SAME: with(%[[SPLAT]] as %[[BB2_SPLAT:.+]]: !stream.resource<transient>{%c1280})
  // CHECK-SAME: -> %[[SPLAT]]{%c1280}
  // CHECK: stream.async.dispatch @ex::@dispatch_1[%c1, %c1, %c1](%[[BB2_SPLAT]]) : (!stream.resource<transient>{%c1280}) -> %[[BB2_SPLAT]]{%c1280}
  %4 = stream.async.dispatch @ex::@dispatch_1[%c1, %c1, %c1](%splat) : (!stream.resource<transient>{%c1280}) -> %splat{%c1280}
  // CHECK: %[[BB2_READY:.+]] = stream.timepoint.await %[[BB2_TIMEPOINT]] => %[[BB2_RESULT]]
  // CHECK: return %[[BB2_READY]]
  return %4 : !stream.resource<transient>
}

// -----

// Tests a complex device->host->device sequence gets turned into the proper
// execute->await->execute. These data-dependent operations can happen in a
// single block and break the assumption that one block == one partition.

// CHECK-LABEL: @deviceHostDevice
func @deviceHostDevice() -> !stream.resource<transient> {
  %c0 = arith.constant 0 : index
  %c1 = arith.constant 1 : index
  %c123_i8 = arith.constant 123 : i8
  // CHECK: %[[RESULT_D2H:.+]], %[[TIMEPOINT_D2H:.+]] = stream.async.execute with()
  // CHECK-SAME: -> !stream.resource<staging>{%c1}
  // CHECK-NEXT: %[[SPLAT:.+]] = stream.async.splat %c123_i8
  %0 = stream.async.splat %c123_i8 : i8 -> !stream.resource<transient>{%c1}
  // CHECK-NEXT: %[[TRANSFER_D2H:.+]] = stream.async.transfer %[[SPLAT]]
  %1 = stream.async.transfer %0 : !stream.resource<transient>{%c1} -> !stream.resource<staging>{%c1}
  // CHECK-NEXT: stream.yield %[[TRANSFER_D2H]]
  // CHECK: %[[READY_D2H:.+]] = stream.timepoint.await %[[TIMEPOINT_D2H]] => %[[RESULT_D2H]] : !stream.resource<staging>{%c1}
  // CHECK: %[[LOAD:.+]] = stream.async.load %[[READY_D2H]]
  %2 = stream.async.load %1[%c0] : !stream.resource<staging>{%c1} -> i8
  // CHECK: %[[ADD:.+]] = arith.addi %[[LOAD]], %[[LOAD]]
  %3 = arith.addi %2, %2 : i8
  // CHECK: %[[STORE:.+]] = stream.async.store %[[ADD]], %[[READY_D2H]]
  %4 = stream.async.store %3, %1[%c0] : i8 -> !stream.resource<staging>{%c1}
  // CHECK: %[[RESULT_H2D:.+]], %[[TIMEPOINT_H2D:.+]] = stream.async.execute
  // CHECK-SAME: with(%[[STORE]] as %[[STORE_CAPTURE:.+]]: !stream.resource<staging>{%c1})
  // CHECK-SAME: -> !stream.resource<transient>{%c1}
  // CHECK-NEXT: %[[TRANSFER_H2D:.+]] = stream.async.transfer %[[STORE_CAPTURE]]
  %5 = stream.async.transfer %4 : !stream.resource<staging>{%c1} -> !stream.resource<transient>{%c1}
  // CHECK-NEXT: stream.yield %[[TRANSFER_H2D]]
  // CHECK: %[[READY_H2D:.+]] = stream.timepoint.await %[[TIMEPOINT_H2D]] => %[[RESULT_H2D]] : !stream.resource<transient>{%c1}
  // CHECK: return %[[READY_H2D]]
  return %5 : !stream.resource<transient>
}
