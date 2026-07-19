#!/usr/bin/env bash
# checks/universal/quality/check-cpp-you-dont-need.sh
# @see ADR-129
# "You Don't Need" for C++ — Boost features now in std, deprecated patterns
set -o nounset -o pipefail

REPO="${1:-.}"
SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src"
[ -z "$SRC" ] && exit 0

# Only run if C++ files exist
find "$SRC" -name "*.cpp" -o -name "*.h" -o -name "*.hpp" 2>/dev/null | head -1 | grep -q . || exit 0

FINDINGS=0
finding() { printf "  \033[33mwarning\033[0m  %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }
error()   { printf "  \033[31merror\033[0m    %-30s %s\n" "$1" "$2"; FINDINGS=$((FINDINGS+1)); }

# =============================================
# BOOST → STD (C++11/14/17/20 replacements)
# =============================================

# boost::shared_ptr → std::shared_ptr (C++11)
if grep -rn "boost::shared_ptr\|boost/shared_ptr" $SRC --include="*.cpp" --include="*.h" 2>/dev/null | head -1 | grep -q .; then
  finding "cpp-boost-shared-ptr" "boost::shared_ptr — use std::shared_ptr (C++11)"
fi

# boost::unique_ptr → std::unique_ptr (C++11)
if grep -rn "boost::scoped_ptr\|boost/scoped_ptr" $SRC --include="*.cpp" --include="*.h" 2>/dev/null | head -1 | grep -q .; then
  finding "cpp-boost-scoped-ptr" "boost::scoped_ptr — use std::unique_ptr (C++11)"
fi

# boost::thread → std::thread (C++11)
if grep -rn "boost::thread\|boost/thread" $SRC --include="*.cpp" --include="*.h" 2>/dev/null | head -1 | grep -q .; then
  finding "cpp-boost-thread" "boost::thread — use std::thread + std::mutex (C++11)"
fi

# boost::regex → std::regex (C++11)
if grep -rn "boost::regex\|boost/regex" $SRC --include="*.cpp" --include="*.h" 2>/dev/null | head -1 | grep -q .; then
  finding "cpp-boost-regex" "boost::regex — use std::regex (C++11, or RE2 for performance)"
fi

# boost::optional → std::optional (C++17)
if grep -rn "boost::optional\|boost/optional" $SRC --include="*.cpp" --include="*.h" 2>/dev/null | head -1 | grep -q .; then
  finding "cpp-boost-optional" "boost::optional — use std::optional (C++17)"
fi

# boost::variant → std::variant (C++17)
if grep -rn "boost::variant\|boost/variant" $SRC --include="*.cpp" --include="*.h" 2>/dev/null | head -1 | grep -q .; then
  finding "cpp-boost-variant" "boost::variant — use std::variant (C++17)"
fi

# boost::any → std::any (C++17)
if grep -rn "boost::any\|boost/any" $SRC --include="*.cpp" --include="*.h" 2>/dev/null | head -1 | grep -q .; then
  finding "cpp-boost-any" "boost::any — use std::any (C++17)"
fi

# boost::filesystem → std::filesystem (C++17)
if grep -rn "boost::filesystem\|boost/filesystem" $SRC --include="*.cpp" --include="*.h" 2>/dev/null | head -1 | grep -q .; then
  finding "cpp-boost-filesystem" "boost::filesystem — use std::filesystem (C++17)"
fi

# boost::string_view → std::string_view (C++17)
if grep -rn "boost::string_view\|boost/string_view" $SRC --include="*.cpp" --include="*.h" 2>/dev/null | head -1 | grep -q .; then
  finding "cpp-boost-string-view" "boost::string_view — use std::string_view (C++17)"
fi

# boost::mutex/lock_guard → std::mutex (C++11)
if grep -rn "boost::mutex\|boost::lock_guard\|boost/mutex" $SRC --include="*.cpp" --include="*.h" 2>/dev/null | head -1 | grep -q .; then
  finding "cpp-boost-mutex" "boost::mutex/lock_guard — use std::mutex + std::lock_guard (C++11)"
fi

# =============================================
# DEPRECATED C++ PATTERNS
# =============================================

# auto_ptr → unique_ptr (removed in C++17)
if grep -rn "auto_ptr\|std::auto_ptr" $SRC --include="*.cpp" --include="*.h" 2>/dev/null | head -1 | grep -q .; then
  error "cpp-auto-ptr" "std::auto_ptr removed in C++17 — use std::unique_ptr"
fi

# register keyword (deprecated C++11, removed C++17)
if grep -rn "^\s*register\s" $SRC --include="*.cpp" --include="*.c" 2>/dev/null | head -1 | grep -q .; then
  finding "cpp-register" "'register' keyword deprecated (C++11), removed (C++17) — compiler ignores it"
fi

# NULL → nullptr (C++11)
if grep -rn "\bNULL\b" $SRC --include="*.cpp" --include="*.h" 2>/dev/null | grep -v "// \|define\|ifdef" | head -1 | grep -q .; then
  finding "cpp-use-nullptr" "NULL macro — use nullptr (type-safe, C++11)"
fi

# C-style casts → static_cast/dynamic_cast
if grep -rn "(\(int\|char\|float\|double\|void\)\s*\*\?\s*)" $SRC --include="*.cpp" 2>/dev/null | grep -v "test\|// " | head -1 | grep -q .; then
  finding "cpp-c-style-cast" "C-style cast (int)x — use static_cast<int>(x) for safety"
fi

# #define constants → constexpr (C++11)
if grep -rn "^#define\s\+[A-Z_]\+\s\+[0-9]" $SRC --include="*.h" --include="*.hpp" 2>/dev/null | grep -v "GUARD\|_H\b\|_HPP\b" | head -1 | grep -q .; then
  finding "cpp-define-constexpr" "#define numeric constant — use constexpr (type-safe, scoped)"
fi

# printf/sprintf → std::format (C++20) or fmt::format
if grep -rn "sprintf\|printf" $SRC --include="*.cpp" 2>/dev/null | grep -v "snprintf\|fprintf\|test\|// " | head -1 | grep -q .; then
  finding "cpp-use-format" "printf/sprintf — consider std::format (C++20) or fmt::format for type safety"
fi

# using namespace std (pollutes global namespace)
if grep -rn "using namespace std" $SRC --include="*.cpp" --include="*.h" 2>/dev/null | head -1 | grep -q .; then
  finding "cpp-using-namespace-std" "'using namespace std' — pollutes global namespace, use std:: prefix"
fi

# atoi/atof → stoi/stod (C++11, throws on error)
if grep -rn "\batoi\b\|\batof\b\|\batol\b" $SRC --include="*.cpp" 2>/dev/null | grep -v "test\|// " | head -1 | grep -q .; then
  finding "cpp-atoi" "atoi/atof — use std::stoi/stod (C++11, throws on invalid input)"
fi

# new/delete for arrays → std::vector or std::unique_ptr<T[]>
if grep -rn "new\s\+[a-zA-Z_]\+\[" $SRC --include="*.cpp" 2>/dev/null | grep -v "test\|placement" | head -1 | grep -q .; then
  finding "cpp-new-array" "new T[] — use std::vector<T> or std::unique_ptr<T[]> (RAII, no leaks)"
fi

# strcat/strcpy → std::string or snprintf
if grep -rn "\bstrcpy\b\|\bstrcat\b" $SRC --include="*.cpp" --include="*.c" 2>/dev/null | head -1 | grep -q .; then
  error "cpp-unsafe-string" "strcpy/strcat — buffer overflow risk, use std::string or snprintf"
fi

[ "$FINDINGS" -eq 0 ] && printf "  \033[32m✓\033[0m  C++: using modern patterns\n"
exit 0
