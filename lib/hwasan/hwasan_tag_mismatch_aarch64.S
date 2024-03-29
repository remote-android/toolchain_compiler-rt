#include "sanitizer_common/sanitizer_asm.h"

// The content of this file is AArch64-only:
#if defined(__aarch64__)

// The responsibility of the HWASan entry point in compiler-rt is to primarily
// readjust the stack from the callee and save the current register values to
// the stack.
// This entry point function should be called from a __hwasan_check_* symbol.
// These are generated during a lowering pass in the backend, and are found in
// AArch64AsmPrinter::EmitHwasanMemaccessSymbols(). Please look there for
// further information.
// The __hwasan_check_* caller of this function should have expanded the stack
// and saved the previous values of x0, x1, x29, and x30. This function will
// "consume" these saved values and treats it as part of its own stack frame.
// In this sense, the __hwasan_check_* callee and this function "share" a stack
// frame. This allows us to omit having unwinding information (.cfi_*) present
// in every __hwasan_check_* function, therefore reducing binary size. This is
// particularly important as hwasan_check_* instances are duplicated in every
// translation unit where HWASan is enabled.
// This function calls HwasanTagMismatch to step back into the C++ code that
// completes the stack unwinding and error printing. This function is is not
// permitted to return.


// Frame from __hwasan_check_:
// |              ...                |
// |              ...                |
// | Previous stack frames...        |
// +=================================+
// | Unused 8-bytes for maintaining  |
// | 16-byte SP alignment.           |
// +---------------------------------+
// | Return address (x30) for caller |
// | of __hwasan_check_*.            |
// +---------------------------------+
// | Frame address (x29) for caller  |
// | of __hwasan_check_*             |
// +---------------------------------+ <-- [SP + 232]
// |              ...                |
// |                                 |
// | Stack frame space for x2 - x28. |
// |                                 |
// |              ...                |
// +---------------------------------+ <-- [SP + 16]
// |                                 |
// | Saved x1, as __hwasan_check_*   |
// | clobbers it.                    |
// +---------------------------------+
// | Saved x0, likewise above.       |
// +---------------------------------+ <-- [x30 / SP]

// This function takes two arguments:
//   * x0: The address of read/write instruction that caused HWASan check fail.
//   * x1: The tag size.

.section .text
.file "hwasan_tag_mismatch_aarch64.S"
.global __hwasan_tag_mismatch
.type __hwasan_tag_mismatch, %function
__hwasan_tag_mismatch:
  CFI_STARTPROC

  // Set the CFA to be the return address for caller of __hwasan_check_*. Note
  // that we do not emit CFI predicates to describe the contents of this stack
  // frame, as this proxy entry point should never be debugged. The contents
  // are static and are handled by the unwinder after calling
  // __hwasan_tag_mismatch. The frame pointer is already correctly setup
  // by __hwasan_check_*.
  add x29, sp, #232
  CFI_DEF_CFA(w29, 24)
  CFI_OFFSET(w30, -16)
  CFI_OFFSET(w29, -24)

  // Save the rest of the registers into the preallocated space left by
  // __hwasan_check.
  str     x28,      [sp, #224]
  stp     x26, x27, [sp, #208]
  stp     x24, x25, [sp, #192]
  stp     x22, x23, [sp, #176]
  stp     x20, x21, [sp, #160]
  stp     x18, x19, [sp, #144]
  stp     x16, x17, [sp, #128]
  stp     x14, x15, [sp, #112]
  stp     x12, x13, [sp, #96]
  stp     x10, x11, [sp, #80]
  stp     x8,  x9,  [sp, #64]
  stp     x6,  x7,  [sp, #48]
  stp     x4,  x5,  [sp, #32]
  stp     x2,  x3,  [sp, #16]

  // Pass the address of the frame to __hwasan_tag_mismatch_stub, so that it can
  // extract the saved registers from this frame without having to worry about
  // finding this frame.
  mov x2, sp

  bl __hwasan_tag_mismatch_stub
  CFI_ENDPROC

.Lfunc_end0:
  .size __hwasan_tag_mismatch, .Lfunc_end0-__hwasan_tag_mismatch

.addrsig

#endif  // defined(__aarch64__)

// We do not need executable stack.
NO_EXEC_STACK_DIRECTIVE
