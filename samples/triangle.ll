; ModuleID = 'triangle'

@0 = private unnamed_addr constant [23 x i8] c"Enter triangle depth: \00"
@1 = private unnamed_addr constant [3 x i8] c"%d\00"
@2 = private unnamed_addr constant [2 x i8] c" \00"
@3 = private unnamed_addr constant [2 x i8] c"*\00"
@4 = private unnamed_addr constant [2 x i8] c"\0A\00"
@5 = private unnamed_addr constant [13 x i8] c"Hello World\0A\00"

define i32 @main() {
entry:
  %x = alloca i32
  %j = alloca i32
  %i = alloca i32
  %n = alloca i32
  %0 = call i32 (i8*, ...)* @printf(i8* getelementptr inbounds ([23 x i8]* @0, i32 0, i32 0))
  %calltmp = call i32 (i8*, ...)* @scanf(i8* getelementptr inbounds ([3 x i8]* @1, i32 0, i32 0), i32* %n)
  store i32 1, i32* %i
  %i1 = load i32* %i
  %n2 = load i32* %n
  %1 = icmp sle i32 %i1, %n2
  %2 = uitofp i1 %1 to double
  %loopCond = fcmp one double %2, 0.000000e+00
  br i1 %loopCond, label %loop, label %afterloop

loop:                                             ; preds = %afterloop22, %entry
  store i32 0, i32* %j
  %j3 = load i32* %j
  %n4 = load i32* %n
  %i5 = load i32* %i
  %3 = sub i32 %n4, %i5
  %4 = icmp slt i32 %j3, %3
  %5 = uitofp i1 %4 to double
  %loopCond6 = fcmp one double %5, 0.000000e+00
  br i1 %loopCond6, label %loop7, label %afterloop8

afterloop:                                        ; preds = %afterloop22, %entry
  store i32 0, i32* %x
  %x34 = load i32* %x
  %6 = icmp sgt i32 %x34, 0
  %7 = uitofp i1 %6 to double
  %loopcond = fcmp one double %7, 0.000000e+00
  br i1 %loopcond, label %loop33, label %afterLoop

loop7:                                            ; preds = %loop7, %loop
  %8 = call i32 (i8*, ...)* @printf(i8* getelementptr inbounds ([2 x i8]* @2, i32 0, i32 0))
  %j9 = load i32* %j
  %9 = add i32 %j9, 1
  store i32 %9, i32* %j
  %j10 = load i32* %j
  %n11 = load i32* %n
  %i12 = load i32* %i
  %10 = sub i32 %n11, %i12
  %11 = icmp slt i32 %j10, %10
  %12 = uitofp i1 %11 to double
  %loopCond13 = fcmp one double %12, 0.000000e+00
  br i1 %loopCond13, label %loop7, label %afterloop8

afterloop8:                                       ; preds = %loop7, %loop
  %n14 = load i32* %n
  %i15 = load i32* %i
  %13 = sub i32 %n14, %i15
  store i32 %13, i32* %j
  %j16 = load i32* %j
  %n17 = load i32* %n
  %i18 = load i32* %i
  %14 = sub i32 %n17, %i18
  %i19 = load i32* %i
  %15 = mul i32 2, %i19
  %16 = add i32 %14, %15
  %17 = sub i32 %16, 1
  %18 = icmp slt i32 %j16, %17
  %19 = uitofp i1 %18 to double
  %loopCond20 = fcmp one double %19, 0.000000e+00
  br i1 %loopCond20, label %loop21, label %afterloop22

loop21:                                           ; preds = %loop21, %afterloop8
  %20 = call i32 (i8*, ...)* @printf(i8* getelementptr inbounds ([2 x i8]* @3, i32 0, i32 0))
  %j23 = load i32* %j
  %21 = add i32 %j23, 1
  store i32 %21, i32* %j
  %j24 = load i32* %j
  %n25 = load i32* %n
  %i26 = load i32* %i
  %22 = sub i32 %n25, %i26
  %i27 = load i32* %i
  %23 = mul i32 2, %i27
  %24 = add i32 %22, %23
  %25 = sub i32 %24, 1
  %26 = icmp slt i32 %j24, %25
  %27 = uitofp i1 %26 to double
  %loopCond28 = fcmp one double %27, 0.000000e+00
  br i1 %loopCond28, label %loop21, label %afterloop22

afterloop22:                                      ; preds = %loop21, %afterloop8
  %28 = call i32 (i8*, ...)* @printf(i8* getelementptr inbounds ([2 x i8]* @4, i32 0, i32 0))
  %i29 = load i32* %i
  %29 = add i32 %i29, 1
  store i32 %29, i32* %i
  %i30 = load i32* %i
  %n31 = load i32* %n
  %30 = icmp sle i32 %i30, %n31
  %31 = uitofp i1 %30 to double
  %loopCond32 = fcmp one double %31, 0.000000e+00
  br i1 %loopCond32, label %loop, label %afterloop

loop33:                                           ; preds = %loop33, %afterloop
  %32 = call i32 (i8*, ...)* @printf(i8* getelementptr inbounds ([13 x i8]* @5, i32 0, i32 0))
  %x35 = load i32* %x
  %33 = icmp sgt i32 %x35, 0
  %34 = uitofp i1 %33 to double
  %loopcond36 = fcmp one double %34, 0.000000e+00
  br i1 %loopcond36, label %loop33, label %afterLoop

afterLoop:                                        ; preds = %loop33, %afterloop
  ret i32 0
}

declare i32 @printf(i8*, ...)

declare i32 @scanf(i8*, ...)
