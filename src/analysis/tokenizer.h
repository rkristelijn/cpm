/**
 * @file tokenizer.h
 * @brief Language-aware tokenizer — strips comments and strings from source code.
 *
 * Zero external dependencies. Single-pass O(n) state machine.
 * Supports 15+ languages via a static syntax table.
 *
 * Usage:
 *   auto* syntax = lang_syntax(".cpp");
 *   if (syntax) {
 *     std::string code_only = strip_comments(content, syntax);
 *     std::string bare      = strip_comments_and_strings(content, syntax);
 *   }
 *
 * Line structure is preserved: comments/strings are replaced with spaces,
 * newlines are kept. This means line numbers in the output match the input.
 */
#ifndef CPM_ANALYSIS_TOKENIZER_H
#define CPM_ANALYSIS_TOKENIZER_H

#include <string>

/** @brief Syntax rules for a single language family. */
struct LangSyntax {
  const char* extensions[8];  // file extensions (e.g. ".cpp", ".h")
  const char* line_comment;   // "//" or "#" or "--" or nullptr
  const char* block_start;    // "/*" or "<!--" or nullptr
  const char* block_end;      // "*/" or "-->" or nullptr
  char string_delims[4];      // e.g. '"', '\'', '`', 0
  bool triple_strings;        // Python/Kotlin triple-quoted strings
};

/**
 * @brief Look up syntax rules for a file extension.
 * @param extension  File extension including dot (e.g. ".cpp", ".py")
 * @return Pointer to static LangSyntax, or nullptr if unknown.
 */
const LangSyntax* lang_syntax(const std::string& extension);

/**
 * @brief Strip comments from source code, preserving line structure.
 *
 * Comment characters are replaced with spaces; newlines are preserved.
 * String literals are left intact (comments inside strings are not stripped).
 *
 * @param content  Source file content.
 * @param syntax   Language syntax rules (from lang_syntax). If nullptr, returns content unchanged.
 * @return Source with comments replaced by spaces.
 */
std::string strip_comments(const std::string& content, const LangSyntax* syntax);

/**
 * @brief Strip both comments AND string literals, preserving line structure.
 *
 * Both comment and string characters are replaced with spaces.
 * Useful for checks that should ignore string content (e.g. complexity, dead code).
 *
 * @param content  Source file content.
 * @param syntax   Language syntax rules (from lang_syntax). If nullptr, returns content unchanged.
 * @return Source with comments and strings replaced by spaces.
 */
std::string strip_comments_and_strings(const std::string& content, const LangSyntax* syntax);

#endif
