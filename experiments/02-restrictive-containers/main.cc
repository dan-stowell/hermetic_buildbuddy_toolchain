#include <iostream>

#include "absl/strings/str_cat.h"

int main() {
  // Forces abseil-cpp to actually compile and link remotely.
  std::cout << absl::StrCat("hello ", "buildbuddy rbe ", 2026) << std::endl;
  return 0;
}
