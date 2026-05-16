/**
 * @file checks_test.cpp
 * @brief Unit tests for all native checks — uses MockFileSystem, instant.
 */
#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include "../vendor/doctest.h"

#include "checks/check.h"
#include "io/mock_fs.h"
#include "runners/tool_runner.h"

/* Include all check implementations */
#include "checks/secrets.cpp"
#include "checks/todo.cpp"
#include "checks/lockfile.cpp"
#include "checks/filesize.cpp"
#include "checks/comments.cpp"
#include "checks/inclusivity.cpp"
#include "checks/pii.cpp"
#include "checks/slop.cpp"
#include "checks/portability.cpp"
#include "checks/unicode.cpp"
#include "checks/version_pins.cpp"
#include "checks/imports.cpp"
#include "checks/async.cpp"
#include "checks/dangerous.cpp"
#include "checks/complexity.cpp"
#include "checks/dead_docs.cpp"
#include "checks/runtime_eol.cpp"
#include "checks/makefile.cpp"

/* === Secrets === */
TEST_CASE("secrets: detects API keys") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("src/main.cpp", "auto key = \"sk-12345678901234567890\";");
  CHECK(SecretsCheck().run(fs, r).size() == 1);
}
TEST_CASE("secrets: clean file") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("src/main.cpp", "int main() { return 0; }");
  CHECK(SecretsCheck().run(fs, r).empty());
}
TEST_CASE("secrets: respects cpm:ignore") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("src/main.cpp", "// cpm:ignore secret\nauto k = \"sk-12345678901234567890\";");
  CHECK(SecretsCheck().run(fs, r).empty());
}

/* === TODO === */
TEST_CASE("todo: finds markers") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("src/x.cpp", "// TODO fix\n// FIXME broken");
  CHECK(TodoCheck().run(fs, r).size() == 2);
}

/* === Lockfile === */
TEST_CASE("lockfile: missing npm lock") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("package.json", "{}");
  CHECK(LockfileCheck().run(fs, r).size() == 1);
}
TEST_CASE("lockfile: yarn.lock present") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("package.json", "{}");
  fs.add_file("yarn.lock", "");
  CHECK(LockfileCheck().run(fs, r).empty());
}

/* === File size === */
TEST_CASE("filesize: large file") {
  MockFileSystem fs; MockToolRunner r;
  std::string big(700, '\n');
  fs.add_file("src/big.cpp", big);
  CHECK(FileSizeCheck().run(fs, r).size() == 1);
}
TEST_CASE("filesize: normal file") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("src/ok.cpp", "int main() {}\n");
  CHECK(FileSizeCheck().run(fs, r).empty());
}

/* === Comments === */
TEST_CASE("comments: low ratio") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("src/x.cpp", "int a;\nint b;\nint c;\nint d;\nint e;\n");
  auto f = CommentRatioCheck().run(fs, r);
  CHECK(f.size() == 1);
  CHECK(f[0].rule == "low-comment-ratio");
}

/* === Inclusivity === */
TEST_CASE("inclusivity: flags whitelist") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("src/x.cpp", "// add to whitelist\n");
  CHECK(InclusivityCheck().run(fs, r).size() == 1);
}

/* === PII === */
TEST_CASE("pii: detects email") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("src/x.cpp", "auto email = \"user@example.com\";");
  CHECK(PiiCheck().run(fs, r).size() == 1);
}

/* === Slop === */
TEST_CASE("slop: detects AI filler") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("src/x.cpp", "// Certainly! Let me help");
  CHECK(SlopCheck().run(fs, r).size() == 1);
}

/* === Portability === */
TEST_CASE("portability: hardcoded path sep") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("src/x.cpp", "auto p = dir + \"/\" + name;");
  CHECK(PortabilityCheck().run(fs, r).size() == 1);
}

/* === Version pins === */
TEST_CASE("version-pins: unpinned npm") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("package.json", "{\"deps\": {\"a\": \"^1.0.0\"}}");
  CHECK(VersionPinsCheck().run(fs, r).size() == 1);
}

/* === Imports === */
TEST_CASE("imports: deep relative") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("src/x.ts", "import { foo } from '../../../bar';");
  CHECK(ImportsCheck().run(fs, r).size() == 1);
}

/* === Dangerous === */
TEST_CASE("dangerous: eval") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("src/x.ts", "eval(input);");
  auto f = DangerousCheck().run(fs, r);
  CHECK(f.size() == 1);
  CHECK(f[0].severity == "error");
}

/* === Complexity === */
TEST_CASE("complexity: god class") {
  MockFileSystem fs; MockToolRunner r;
  std::string code;
  for (int i = 0; i < 12; i++) code += "  async method" + std::to_string(i) + "() {}\n";
  fs.add_file("src/x.ts", code);
  CHECK(ComplexityCheck().run(fs, r).size() == 1);
}

/* === Runtime EOL === */
TEST_CASE("runtime-eol: old node") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file(".nvmrc", "16");
  CHECK(RuntimeEolCheck().run(fs, r).size() == 1);
}
TEST_CASE("runtime-eol: current node") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file(".nvmrc", "22");
  CHECK(RuntimeEolCheck().run(fs, r).empty());
}

/* === Makefile === */
TEST_CASE("makefile: no phony") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("Makefile", "build:\n\tgcc main.c");
  CHECK(MakefileCheck().run(fs, r).size() >= 1);
}

#include "checks/crypto.cpp"

TEST_CASE("crypto: detects weak SSL") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("src/server.ts", "const ctx = tls.createSecureContext({ secureProtocol: \"SSLv3\" });");
  auto f = CryptoCheck().run(fs, r);
  CHECK(f.size() == 1);
  CHECK(f[0].rule == "weak-ssl");
}

TEST_CASE("crypto: detects disabled cert verification") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("src/api.ts", "const agent = new https.Agent({ rejectUnauthorized: false });");
  auto f = CryptoCheck().run(fs, r);
  CHECK(f.size() == 1);
  CHECK(f[0].rule == "no-cert-verify");
}

TEST_CASE("crypto: clean file passes") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("src/main.cpp", "int main() { return 0; }");
  CHECK(CryptoCheck().run(fs, r).empty());
}

#include "checks/owasp.cpp"

TEST_CASE("owasp: detects SQL injection pattern") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("src/api.ts", "const q = `SELECT * FROM users WHERE id = ` + req.params.id;");
  auto f = OwaspCheck().run(fs, r);
  CHECK(f.size() >= 1);
  CHECK(f[0].rule == "a05-sql-concat");
}

TEST_CASE("owasp: detects XSS via innerHTML") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("src/ui.ts", "el.innerHTML = userInput;");
  CHECK(OwaspCheck().run(fs, r).size() == 1);
}

TEST_CASE("owasp: detects debug mode") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("src/config.ts", "export const config = { debug: true };");
  CHECK(OwaspCheck().run(fs, r).size() == 1);
}

TEST_CASE("owasp: detects empty catch") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("src/x.ts", "try { foo(); } catch {}");
  CHECK(OwaspCheck().run(fs, r).size() == 1);
}

TEST_CASE("owasp: clean file passes") {
  MockFileSystem fs; MockToolRunner r;
  fs.add_file("src/main.cpp", "int main() { return 0; }");
  CHECK(OwaspCheck().run(fs, r).empty());
}
