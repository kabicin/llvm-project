; Test that zext (extract element 1 of (add nuw (shuffle X), X)) with X of type
; v2i64 is selected as VECTOR SUM ACROSS QUADWORD instead of going through a
; general register.
;
; RUN: llc < %s -mtriple=s390x-linux-gnu -mcpu=z14 | FileCheck %s

; Sum of the two doublewords, no unsigned wrap: use VSUMQG.
define i128 @f1(<2 x i64> %x) {
; CHECK-LABEL: f1:
; CHECK: vgbm [[ZERO:%v[0-9]+]], 0
; CHECK: vsumqg %v0, %v24, [[ZERO]]
; CHECK-NOT: vlgvg
; CHECK-NOT: vlvgg
; CHECK: br %r14
  %s = shufflevector <2 x i64> %x, <2 x i64> poison, <2 x i32> <i32 poison, i32 0>
  %a = add nuw <2 x i64> %s, %x
  %e = extractelement <2 x i64> %a, i64 1
  %r = zext i64 %e to i128
  ret i128 %r
}

; Operands of the add in the other order.
define i128 @f2(<2 x i64> %x) {
; CHECK-LABEL: f2:
; CHECK: vsumqg
; CHECK-NOT: vlgvg
; CHECK: br %r14
  %s = shufflevector <2 x i64> %x, <2 x i64> poison, <2 x i32> <i32 poison, i32 0>
  %a = add nuw <2 x i64> %x, %s
  %e = extractelement <2 x i64> %a, i64 1
  %r = zext i64 %e to i128
  ret i128 %r
}

; Without nuw the 64-bit add may wrap, so VSUMQG (a 128-bit sum) is not
; equivalent and must not be used.
define i128 @f3(<2 x i64> %x) {
; CHECK-LABEL: f3:
; CHECK-NOT: vsumqg
; CHECK: br %r14
  %s = shufflevector <2 x i64> %x, <2 x i64> poison, <2 x i32> <i32 poison, i32 0>
  %a = add <2 x i64> %s, %x
  %e = extractelement <2 x i64> %a, i64 1
  %r = zext i64 %e to i128
  ret i128 %r
}

; Extracting element 0 instead of element 1 is a different value.
define i128 @f4(<2 x i64> %x) {
; CHECK-LABEL: f4:
; CHECK-NOT: vsumqg
; CHECK: br %r14
  %s = shufflevector <2 x i64> %x, <2 x i64> poison, <2 x i32> <i32 poison, i32 0>
  %a = add nuw <2 x i64> %s, %x
  %e = extractelement <2 x i64> %a, i64 0
  %r = zext i64 %e to i128
  ret i128 %r
}
