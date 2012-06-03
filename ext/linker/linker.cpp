/*
 * Linker bindings for LLVM.
 */

#include "llvm/Linker.h"
using namespace llvm;

#include <cctype>
#include "linker.h"

extern "C" {
	LLVMBool LLVMLinkModules(LLVMModuleRef Dest, LLVMModuleRef Src,
	                         LLVMLinkerMode Mode, char **OutMessages) {
	  std::string Messages;
	  LLVMBool Result = Linker::LinkModules(unwrap(Dest), unwrap(Src),
	                                        Mode, OutMessages? &Messages : 0);
	  if (OutMessages)
	  *OutMessages = strdup(Messages.c_str());
	  return Result;
	}
}