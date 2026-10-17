#include "CxxChecks.h"
#include "SwiftCxxExceptionShim.h"

#include <stdexcept>
#include <string>

namespace {

void copyMessage(void *context, const char *message) noexcept {
  *static_cast<std::string *>(context) = message;
}

} // namespace

// Mirrors the adapter that swiftlang/swift#92563 generates for a throwing C++ function.
extern "C" int cxx_check_swift_exception_bridge(void) {
  std::string message;
  try {
    throw std::runtime_error("division by zero");
  } catch (...) {
    __swift_cxx_report_current_exception(&message, copyMessage);
  }
  return message == "division by zero";
}
