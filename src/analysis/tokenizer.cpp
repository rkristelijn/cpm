/**
 * @file tokenizer.cpp
 * @brief Language-aware tokenizer — single-pass state machine.
 *
 * State machine walks char-by-char through source code, tracking whether
 * we're in normal code, a line comment, a block comment, a string, or
 * a triple-quoted string. Characters in comment/string regions are replaced
 * with spaces (newlines preserved) so line numbers stay correct.
 *
 * Performance: O(n) single pass, no allocations beyond the output string.
 * No external dependencies — only standard C++ and <cstring>.
 */
#include "tokenizer.h"

#include <cstring>

// --- Syntax table ---
// Each entry defines comment/string syntax for a language family.
// Order doesn't matter — lookup is by extension match.

static const LangSyntax SYNTAX_TABLE[] = {
    // C / C++ / Java / C# / Go / Rust / Swift / Kotlin
    {
        {".c", ".cpp", ".h", ".hpp", ".java", ".cs", ".go", ".rs"},
        "//",  // line comment
        "/*",  // block start
        "*/",  // block end
        {'"', '\'', 0, 0},
        false,  // no triple strings
    },
    // Swift / Kotlin (separate entry for .swift, .kt — same syntax)
    {
        {".swift", ".kt", nullptr},
        "//",
        "/*",
        "*/",
        {'"', '\'', 0, 0},
        false,
    },
    // JavaScript / TypeScript (includes template literals)
    {
        {".js", ".ts", ".jsx", ".tsx", ".vue", ".mjs", nullptr},
        "//",
        "/*",
        "*/",
        {'"', '\'', '`', 0},
        false,
    },
    // Python (# comments, triple-quoted strings)
    {
        {".py", nullptr},
        "#",
        nullptr,  // no block comments
        nullptr,
        {'"', '\'', 0, 0},
        true,  // triple strings: """ and '''
    },
    // Ruby (# line comments, =begin/=end block comments)
    {
        {".rb", nullptr},
        "#",
        "=begin",
        "=end",
        {'"', '\'', 0, 0},
        false,
    },
    // PHP (// and # line comments, /* */ block comments)
    {
        {".php", nullptr},
        "//",
        "/*",
        "*/",
        {'"', '\'', 0, 0},
        false,
    },
    // Shell / Bash
    {
        {".sh", ".bash", nullptr},
        "#",
        nullptr,
        nullptr,
        {'"', '\'', 0, 0},
        false,
    },
    // SQL (-- line comments, /* */ block comments)
    {
        {".sql", nullptr},
        "--",
        "/*",
        "*/",
        {'"', '\'', 0, 0},
        false,
    },
    // Lua (-- line comments, --[[ ]] block comments)
    {
        {".lua", nullptr},
        "--",
        "--[[",
        "]]",
        {'"', '\'', 0, 0},
        false,
    },
    // HTML / XML (<!-- --> block comments only)
    {
        {".html", ".htm", ".xml", ".svg", nullptr},
        nullptr,
        "<!--",
        "-->",
        {'"', '\'', 0, 0},
        false,
    },
    // CSS / SCSS / LESS (/* */ block comments only)
    {
        {".css", ".scss", ".less", nullptr},
        nullptr,
        "/*",
        "*/",
        {'"', '\'', 0, 0},
        false,
    },
    // YAML
    {
        {".yml", ".yaml", nullptr},
        "#",
        nullptr,
        nullptr,
        {'"', '\'', 0, 0},
        false,
    },
    // TOML
    {
        {".toml", nullptr},
        "#",
        nullptr,
        nullptr,
        {'"', '\'', 0, 0},
        false,
    },
    // Terraform / HCL
    {
        {".tf", ".hcl", ".tfvars", nullptr},
        "#",
        "/*",
        "*/",
        {'"', 0, 0, 0},
        false,
    },
    // Markdown — no comment syntax (returns entry with all-null comments)
    {
        {".md", nullptr},
        nullptr,
        nullptr,
        nullptr,
        {0, 0, 0, 0},
        false,
    },
};

static const int SYNTAX_COUNT = sizeof(SYNTAX_TABLE) / sizeof(SYNTAX_TABLE[0]);

// --- Extension lookup ---

const LangSyntax* lang_syntax(const std::string& extension) {
  if (extension.empty()) return nullptr;

  for (int i = 0; i < SYNTAX_COUNT; i++) {
    for (int j = 0; j < 8 && SYNTAX_TABLE[i].extensions[j]; j++) {
      if (extension == SYNTAX_TABLE[i].extensions[j]) {
        return &SYNTAX_TABLE[i];
      }
    }
  }
  return nullptr;
}

// --- State machine ---

enum class State {
  NORMAL,
  LINE_COMMENT,
  BLOCK_COMMENT,
  STRING,
  TRIPLE_STRING,
};

/** @brief Check if content at pos starts with prefix. */
static bool match_at(const std::string& s, size_t pos, const char* prefix) {
  if (!prefix) return false;
  size_t len = std::strlen(prefix);
  if (pos + len > s.size()) return false;
  return std::memcmp(s.data() + pos, prefix, len) == 0;
}

/** @brief Check if a character is one of the string delimiters. */
static bool is_string_delim(char c, const char delims[4]) {
  for (int i = 0; i < 4 && delims[i]; i++) {
    if (c == delims[i]) return true;
  }
  return false;
}

/**
 * @brief Core stripping engine.
 * @param content     Source code.
 * @param syntax      Language syntax rules.
 * @param strip_strings  If true, also blank out string literal contents.
 * @return Stripped content with preserved line structure.
 *
 * State machine:
 *   NORMAL        → detect comment starts, string starts
 *   LINE_COMMENT  → blank until newline
 *   BLOCK_COMMENT → blank until block_end
 *   STRING        → track until matching unescaped delimiter
 *   TRIPLE_STRING → track until matching triple delimiter
 *
 * In comment state: replace chars with spaces (keep newlines).
 * In string state:  replace chars with spaces only if strip_strings is true.
 */
static std::string strip_impl(const std::string& content, const LangSyntax* syntax, bool strip_strings) {
  if (!syntax) return content;

  std::string out = content;
  const size_t len = content.size();

  State state = State::NORMAL;
  char string_delim = 0;  // which quote character opened the string
  size_t block_end_len = syntax->block_end ? std::strlen(syntax->block_end) : 0;
  size_t block_start_len = syntax->block_start ? std::strlen(syntax->block_start) : 0;
  size_t line_comment_len = syntax->line_comment ? std::strlen(syntax->line_comment) : 0;

  // PHP also uses # as a secondary line comment
  bool php_hash = false;
  for (int j = 0; j < 8 && syntax->extensions[j]; j++) {
    if (std::strcmp(syntax->extensions[j], ".php") == 0) {
      php_hash = true;
      break;
    }
  }

  size_t i = 0;
  while (i < len) {
    char c = content[i];

    switch (state) {
      case State::NORMAL: {
        // --- Triple-string check (Python: """ or ''') ---
        if (syntax->triple_strings && i + 2 < len && is_string_delim(c, syntax->string_delims) && content[i + 1] == c &&
            content[i + 2] == c) {
          state = State::TRIPLE_STRING;
          string_delim = c;
          if (strip_strings) {
            out[i] = ' ';
            out[i + 1] = ' ';
            out[i + 2] = ' ';
          }
          i += 3;
          continue;
        }

        // --- Block comment start (check before line comment — Lua's --[[ vs --) ---
        if (syntax->block_start && match_at(content, i, syntax->block_start)) {
          state = State::BLOCK_COMMENT;
          for (size_t k = 0; k < block_start_len; k++) {
            out[i + k] = ' ';
          }
          i += block_start_len;
          continue;
        }

        // --- Line comment start ---
        if (syntax->line_comment && match_at(content, i, syntax->line_comment)) {
          state = State::LINE_COMMENT;
          for (size_t k = 0; k < line_comment_len; k++) {
            out[i + k] = ' ';
          }
          i += line_comment_len;
          continue;
        }

        // --- PHP secondary # comment ---
        if (php_hash && c == '#') {
          state = State::LINE_COMMENT;
          out[i] = ' ';
          i++;
          continue;
        }

        // --- String literal start ---
        if (is_string_delim(c, syntax->string_delims)) {
          state = State::STRING;
          string_delim = c;
          if (strip_strings) out[i] = ' ';
          i++;
          continue;
        }

        // Normal character — keep as-is
        i++;
        break;
      }

      case State::LINE_COMMENT: {
        if (c == '\n') {
          // Newline preserved, back to normal
          state = State::NORMAL;
          i++;
        } else {
          out[i] = ' ';
          i++;
        }
        break;
      }

      case State::BLOCK_COMMENT: {
        if (match_at(content, i, syntax->block_end)) {
          for (size_t k = 0; k < block_end_len; k++) {
            out[i + k] = ' ';
          }
          i += block_end_len;
          state = State::NORMAL;
        } else {
          // Preserve newlines for line counting
          if (c != '\n') out[i] = ' ';
          i++;
        }
        break;
      }

      case State::STRING: {
        if (c == '\\') {
          // Escaped character — skip next char (handles \", \\, etc.)
          if (strip_strings) out[i] = ' ';
          i++;
          if (i < len) {
            if (strip_strings) {
              if (content[i] != '\n') out[i] = ' ';
            }
            i++;
          }
        } else if (c == string_delim) {
          // End of string
          if (strip_strings) out[i] = ' ';
          i++;
          state = State::NORMAL;
        } else if (c == '\n') {
          // Unterminated string at EOL — back to normal
          // (most languages don't allow multi-line strings without escaping)
          state = State::NORMAL;
          i++;
        } else {
          if (strip_strings) out[i] = ' ';
          i++;
        }
        break;
      }

      case State::TRIPLE_STRING: {
        // Look for closing triple delimiter (same char × 3)
        if (c == string_delim && i + 2 < len && content[i + 1] == string_delim && content[i + 2] == string_delim) {
          if (strip_strings) {
            out[i] = ' ';
            out[i + 1] = ' ';
            out[i + 2] = ' ';
          }
          i += 3;
          state = State::NORMAL;
        } else {
          // Preserve newlines inside triple strings
          if (strip_strings && c != '\n') out[i] = ' ';
          i++;
        }
        break;
      }
    }
  }

  return out;
}

// --- Public API ---

std::string strip_comments(const std::string& content, const LangSyntax* syntax) { return strip_impl(content, syntax, false); }

std::string strip_comments_and_strings(const std::string& content, const LangSyntax* syntax) { return strip_impl(content, syntax, true); }
