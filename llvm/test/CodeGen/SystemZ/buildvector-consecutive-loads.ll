; Test that a BUILD_VECTOR of consecutive scalar loads, in element order, is
; selected as a single vector load instead of VLREP + VLE.
;
; RUN: llc < %s -mtriple=s390x-linux-gnu -mcpu=z13 | FileCheck %s

; Two adjacent i64 loads, in element order.
define <2 x i64> @f1(ptr %ptr) {
; CHECK-LABEL: f1:
; CHECK: vl %v24, 0(%r2), 3
; CHECK-NOT: vlrepg
; CHECK-NOT: vleg
; CHECK: br %r14
  %ptr1 = getelementptr i64, ptr %ptr, i64 1
  %a = load i64, ptr %ptr, align 8
  %b = load i64, ptr %ptr1, align 8
  %v0 = insertelement <2 x i64> poison, i64 %a, i32 0
  %v1 = insertelement <2 x i64> %v0, i64 %b, i32 1
  ret <2 x i64> %v1
}

; Four adjacent i32 loads, in element order.
define <4 x i32> @f2(ptr %ptr) {
; CHECK-LABEL: f2:
; CHECK: vl %v24, 0(%r2)
; CHECK-NOT: vlrepf
; CHECK-NOT: vlef
; CHECK: br %r14
  %ptr1 = getelementptr i32, ptr %ptr, i64 1
  %ptr2 = getelementptr i32, ptr %ptr, i64 2
  %ptr3 = getelementptr i32, ptr %ptr, i64 3
  %a = load i32, ptr %ptr, align 4
  %b = load i32, ptr %ptr1, align 4
  %c = load i32, ptr %ptr2, align 4
  %d = load i32, ptr %ptr3, align 4
  %v0 = insertelement <4 x i32> poison, i32 %a, i32 0
  %v1 = insertelement <4 x i32> %v0, i32 %b, i32 1
  %v2 = insertelement <4 x i32> %v1, i32 %c, i32 2
  %v3 = insertelement <4 x i32> %v2, i32 %d, i32 3
  ret <4 x i32> %v3
}

; Adjacent loads in the opposite order must not be combined.
define <2 x i64> @f3(ptr %ptr) {
; CHECK-LABEL: f3:
; CHECK: vlrepg %v24, 8(%r2)
; CHECK: vleg %v24, 0(%r2), 1
; CHECK: br %r14
  %ptr1 = getelementptr i64, ptr %ptr, i64 1
  %a = load i64, ptr %ptr, align 8
  %b = load i64, ptr %ptr1, align 8
  %v0 = insertelement <2 x i64> poison, i64 %b, i32 0
  %v1 = insertelement <2 x i64> %v0, i64 %a, i32 1
  ret <2 x i64> %v1
}

; Loads that are not adjacent must not be combined.
define <2 x i64> @f4(ptr %ptr) {
; CHECK-LABEL: f4:
; CHECK: vlrepg %v24, 0(%r2)
; CHECK: vleg %v24, 16(%r2), 1
; CHECK: br %r14
  %ptr1 = getelementptr i64, ptr %ptr, i64 2
  %a = load i64, ptr %ptr, align 8
  %b = load i64, ptr %ptr1, align 8
  %v0 = insertelement <2 x i64> poison, i64 %a, i32 0
  %v1 = insertelement <2 x i64> %v0, i64 %b, i32 1
  ret <2 x i64> %v1
}

; A volatile load must not be combined.
define <2 x i64> @f5(ptr %ptr) {
; CHECK-LABEL: f5:
; CHECK: vlrepg %v24, 0(%r2)
; CHECK: vleg %v24, 8(%r2), 1
; CHECK: br %r14
  %ptr1 = getelementptr i64, ptr %ptr, i64 1
  %a = load volatile i64, ptr %ptr, align 8
  %b = load i64, ptr %ptr1, align 8
  %v0 = insertelement <2 x i64> poison, i64 %a, i32 0
  %v1 = insertelement <2 x i64> %v0, i64 %b, i32 1
  ret <2 x i64> %v1
}

; A loaded value that has another use must not be combined.
define <2 x i64> @f6(ptr %ptr, ptr %dst) {
; CHECK-LABEL: f6:
; CHECK-NOT: vl %v24, 0(%r2), 3
; CHECK: br %r14
  %ptr1 = getelementptr i64, ptr %ptr, i64 1
  %a = load i64, ptr %ptr, align 8
  %b = load i64, ptr %ptr1, align 8
  store i64 %b, ptr %dst
  %v0 = insertelement <2 x i64> poison, i64 %a, i32 0
  %v1 = insertelement <2 x i64> %v0, i64 %b, i32 1
  ret <2 x i64> %v1
}
