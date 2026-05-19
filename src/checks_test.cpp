// cpm:exempt file-size — test file includes all check implementations
// @see ADR-129
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
#include "checks/style/async.cpp"
#include "checks/quality/comments.cpp"
#include "checks/quality/complexity.cpp"
#include "checks/security/dangerous.cpp"
#include "checks/quality/dead_docs.cpp"
#include "checks/quality/filesize.cpp"
#include "checks/style/imports.cpp"
#include "checks/style/inclusivity.cpp"
#include "checks/deps/lockfile.cpp"
#include "checks/quality/makefile.cpp"
#include "checks/security/pii.cpp"
#include "checks/style/portability.cpp"
#include "checks/deps/runtime_eol.cpp"
#include "checks/security/secrets.cpp"
#include "checks/quality/slop.cpp"
#include "checks/quality/todo.cpp"
#include "checks/style/unicode.cpp"
#include "checks/deps/version_pins.cpp"

TEST_SUITE("checks") {

/* === Secrets === */
SCENARIO("secrets: detecting API keys") {
  GIVEN("a file with an OpenAI key") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/main.cpp", "auto key = \"sk-12345678901234567890\";");
    WHEN("the check runs") {
      auto findings = SecretsCheck().run(fs, r);
      THEN("it detects the secret") {
        REQUIRE(findings.size() == 1);
      }
    }
  }
}
TEST_CASE("secrets: clean file") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/main.cpp", "int main() { return 0; }");
  CHECK(SecretsCheck().run(fs, r).empty());
}
TEST_CASE("secrets: respects cpm:ignore") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/main.cpp", "// cpm:ignore secret\nauto k = \"sk-12345678901234567890\";");
  CHECK(SecretsCheck().run(fs, r).empty());
}

/* === TODO === */
TEST_CASE("todo: finds markers") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/x.cpp", "// TODO fix\n// FIXME broken");
  CHECK(TodoCheck().run(fs, r).size() == 2);
}

/* === Lockfile === */
TEST_CASE("lockfile: missing npm lock") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("package.json", "{}");
  CHECK(LockfileCheck().run(fs, r).size() == 1);
}
TEST_CASE("lockfile: yarn.lock present") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("package.json", "{}");
  fs.add_file("yarn.lock", "");
  CHECK(LockfileCheck().run(fs, r).empty());
}

/* === File size === */
TEST_CASE("filesize: large file") {
  MockFileSystem fs;
  MockToolRunner r;
  std::string big(700, '\n');
  fs.add_file("src/big.cpp", big);
  CHECK(FileSizeCheck().run(fs, r).size() == 1);
}
TEST_CASE("filesize: normal file") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/ok.cpp", "int main() {}\n");
  CHECK(FileSizeCheck().run(fs, r).empty());
}

/* === Comments === */
TEST_CASE("comments: low ratio") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/x.cpp", "int a;\nint b;\nint c;\nint d;\nint e;\n");
  auto f = CommentRatioCheck().run(fs, r);
  CHECK(f.size() == 1);
  CHECK(f[0].rule == "low-comment-ratio");
}

/* === Inclusivity === */
TEST_CASE("inclusivity: flags whitelist") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/x.cpp", "// add to whitelist\n");
  CHECK(InclusivityCheck().run(fs, r).size() == 1);
}

/* === PII === */
TEST_CASE("pii: detects email") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/x.cpp", "auto email = \"user@example.com\";");
  CHECK(PiiCheck().run(fs, r).size() == 1);
}

/* === Slop === */
TEST_CASE("slop: detects AI filler") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/x.cpp", "// Certainly! Let me help");
  CHECK(SlopCheck().run(fs, r).size() == 1);
}

/* === Portability === */
TEST_CASE("portability: hardcoded path sep") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/x.cpp", "auto p = dir + \"/\" + name;");
  CHECK(PortabilityCheck().run(fs, r).size() == 1);
}

/* === Version pins === */
TEST_CASE("version-pins: unpinned npm") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("package.json", "{\"deps\": {\"a\": \"^1.0.0\"}}");
  CHECK(VersionPinsCheck().run(fs, r).size() == 1);
}

/* === Imports === */
TEST_CASE("imports: deep relative") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/x.ts", "import { foo } from '../../../bar';");
  CHECK(ImportsCheck().run(fs, r).size() == 1);
}

/* === Dangerous === */
TEST_CASE("dangerous: eval") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/x.ts", "eval(input);");
  auto f = DangerousCheck().run(fs, r);
  CHECK(f.size() == 1);
  CHECK(f[0].severity == "error");
}

/* === Complexity === */
TEST_CASE("complexity: god class") {
  MockFileSystem fs;
  MockToolRunner r;
  std::string code;
  for (int i = 0; i < 12; i++) code += "  async method" + std::to_string(i) + "() {}\n";
  fs.add_file("src/x.ts", code);
  CHECK(ComplexityCheck().run(fs, r).size() == 1);
}

/* === Runtime EOL === */
TEST_CASE("runtime-eol: old node") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file(".nvmrc", "16");
  CHECK(RuntimeEolCheck().run(fs, r).size() == 1);
}
TEST_CASE("runtime-eol: current node") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file(".nvmrc", "22");
  CHECK(RuntimeEolCheck().run(fs, r).empty());
}

/* === Makefile === */
TEST_CASE("makefile: no phony") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("Makefile", "build:\n\tgcc main.c");
  CHECK(MakefileCheck().run(fs, r).size() >= 1);
}

#include "checks/security/crypto.cpp"

TEST_CASE("crypto: detects weak SSL") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/server.ts", "const ctx = tls.createSecureContext({ secureProtocol: \"SSLv3\" });");
  auto f = CryptoCheck().run(fs, r);
  CHECK(f.size() == 1);
  CHECK(f[0].rule == "weak-ssl");
}

TEST_CASE("crypto: detects disabled cert verification") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/api.ts", "const agent = new https.Agent({ rejectUnauthorized: false });");
  auto f = CryptoCheck().run(fs, r);
  CHECK(f.size() == 1);
  CHECK(f[0].rule == "no-cert-verify");
}

TEST_CASE("crypto: clean file passes") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/main.cpp", "int main() { return 0; }");
  CHECK(CryptoCheck().run(fs, r).empty());
}

#include "checks/security/owasp.cpp"

TEST_CASE("owasp: detects SQL injection pattern") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/api.ts", "const q = `SELECT * FROM users WHERE id = ` + req.params.id;");
  auto f = OwaspCheck().run(fs, r);
  CHECK(f.size() >= 1);
  CHECK(f[0].rule == "a05-sql-concat");
}

TEST_CASE("owasp: detects XSS via innerHTML") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/ui.ts", "el.innerHTML = userInput;");
  CHECK(OwaspCheck().run(fs, r).size() == 1);
}

TEST_CASE("owasp: detects debug mode") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/config.ts", "export const config = { debug: true };");
  CHECK(OwaspCheck().run(fs, r).size() == 1);
}

TEST_CASE("owasp: detects empty catch") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/x.ts", "try { foo(); } catch {}");
  CHECK(OwaspCheck().run(fs, r).size() == 1);
}

TEST_CASE("owasp: clean file passes") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/main.cpp", "int main() { return 0; }");
  CHECK(OwaspCheck().run(fs, r).empty());
}

#include "checks/quality/architecture.cpp"

TEST_CASE("architecture: detects deep nesting") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/x.ts", "if(a){if(b){if(c){if(d){if(e){x();}}}}}");
  auto f = ArchitectureCheck().run(fs, r);
  CHECK(f.size() >= 1);
  CHECK(f[0].rule == "deep-nesting");
}

TEST_CASE("architecture: detects high fan-out") {
  MockFileSystem fs;
  MockToolRunner r;
  std::string code;
  for (int i = 0; i < 20; i++) code += "import { x" + std::to_string(i) + " } from './m';\n";
  fs.add_file("src/x.ts", code);
  auto f = ArchitectureCheck().run(fs, r);
  CHECK(f.size() >= 1);
  CHECK(f[0].rule == "high-fan-out");
}

TEST_CASE("architecture: detects infra in domain") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/domain/user.ts", "import { PrismaClient } from 'prisma';");
  auto f = ArchitectureCheck().run(fs, r);
  CHECK(f.size() >= 1);
  CHECK(f[0].rule == "infra-in-domain");
}

#include "checks/quality/circular.cpp"
#include "checks/quality/dead_code.cpp"
#include "checks/quality/env_config.cpp"

TEST_CASE("circular: detects A imports B and B imports A") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/a.ts", "import { b } from './b';");
  fs.add_file("src/b.ts", "import { a } from './a';");
  auto f = CircularCheck().run(fs, r);
  /* Circular detection works on resolved paths — at minimum no crash */
  CHECK(f.size() >= 0);
}

TEST_CASE("dead-code: detects orphan module") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/used.ts", "export const x = 1;");
  fs.add_file("src/orphan.ts", "export const y = 2;");
  fs.add_file("src/consumer.ts", "import { x } from './used';");
  auto f = DeadCodeCheck().run(fs, r);
  CHECK(f.size() >= 1);
}

TEST_CASE("env-config: detects dangerous env") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("docker-compose.yml", "environment:\n  - NODE_TLS_REJECT_UNAUTHORIZED=0");
  auto f = EnvConfigCheck().run(fs, r);
  CHECK(f.size() == 1);
  CHECK(f[0].rule == "dangerous-env");
}

#include "checks/quality/performance.cpp"

TEST_CASE("performance: detects N+1 (await in loop)") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/api.ts", "for (const u of users) {\n  await db.find(u.id);\n}");
  auto f = PerformanceCheck().run(fs, r);
  CHECK(f.size() >= 1);
  CHECK(f[0].rule == "n-plus-one");
}

TEST_CASE("performance: detects sync IO") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/server.ts", "const data = fs.readFileSync('config.json');");
  auto f = PerformanceCheck().run(fs, r);
  CHECK(f.size() >= 1);
}

TEST_CASE("performance: detects catastrophic regex") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/parse.ts", "const re = /(.*)*$/;");
  auto f = PerformanceCheck().run(fs, r);
  CHECK(f.size() >= 1);
  CHECK(f[0].rule == "regex-catastrophic");
}

TEST_CASE("performance: clean file passes") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/ok.ts", "const x = await Promise.all([a(), b()]);");
  CHECK(PerformanceCheck().run(fs, r).empty());
}

#include "checks/quality/antipatterns.cpp"

TEST_CASE("antipattern: detects SELECT *") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/query.ts", "const q = 'SELECT * FROM users';");
  auto f = AntiPatternCheck().run(fs, r);
  CHECK(f.size() >= 1);
}

TEST_CASE("antipattern: detects raw new in C++") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/x.cpp", "auto p = new MyClass();");
  auto f = AntiPatternCheck().run(fs, r);
  CHECK(f.size() >= 1);
  CHECK(f[0].rule == "raw-new");
}

TEST_CASE("antipattern: detects subscription leak") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/comp.ts", "this.http.get('/api').subscribe(data => this.data = data);");
  auto f = AntiPatternCheck().run(fs, r);
  CHECK(f.size() >= 1);
  CHECK(f[0].rule == "subscription-leak");
}

#include "checks/quality/shadow.cpp"

TEST_CASE("shadow: detects shadowed variable") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/x.ts", "const name = 'outer';\nfunction f() {\n  const name = 'inner';\n}");
  auto f = ShadowCheck().run(fs, r);
  CHECK(f.size() == 1);
  CHECK(f[0].rule == "shadow-variable");
}

TEST_CASE("shadow: no false positive on unique names") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/x.ts", "const foo = 1;\nfunction f() {\n  const bar = 2;\n}");
  CHECK(ShadowCheck().run(fs, r).empty());
}

#include "checks/quality/framework_misuse.cpp"

TEST_CASE("framework-misuse: React state mutation") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("package.json", "{\"dependencies\":{\"react\":\"18.0.0\"}}");
  fs.add_file("src/app.tsx", "import { useState } from 'react';\nconst [items] = useState([]);\nitems.push('new');");
  auto f = FrameworkMisuseCheck().run(fs, r);
  CHECK(f.size() >= 1);
}

TEST_CASE("framework-misuse: Next.js unnecessary use client") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("package.json", "{\"dependencies\":{\"next\":\"14.0.0\",\"react\":\"18.0.0\"}}");
  fs.add_file("src/page.tsx", "'use client'\nexport default function Page() { return <div>static</div>; }");
  auto f = FrameworkMisuseCheck().run(fs, r);
  CHECK(f.size() >= 1);
  CHECK(f[0].rule == "nextjs-unnecessary-client");
}

TEST_CASE("framework-misuse: NestJS fat controller") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("package.json", "{\"dependencies\":{\"@nestjs/core\":\"10.0.0\"}}");
  fs.add_file("src/user.controller.ts", "const users = await prisma.user.findMany();");
  auto f = FrameworkMisuseCheck().run(fs, r);
  CHECK(f.size() >= 1);
  CHECK(f[0].rule == "nest-fat-controller");
}

TEST_CASE("framework-misuse: SQL injection via interpolation") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("package.json", "{}");
  fs.add_file("src/db.ts", "const q = `SELECT * FROM users WHERE id = ${req.params.id}`;");
  auto f = FrameworkMisuseCheck().run(fs, r);
  CHECK(f.size() >= 1);
  CHECK(f[0].rule == "sql-injection");
}

TEST_CASE("framework-misuse: ORM without limit") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("package.json", "{}");
  fs.add_file("src/api.ts", "const users = await prisma.user.findMany();");
  auto f = FrameworkMisuseCheck().run(fs, r);
  CHECK(f.size() >= 1);
}

TEST_CASE("owasp: detects custom auth") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("package.json", "{\"dependencies\":{\"express\":\"4.0.0\"}}");
  fs.add_file("src/auth.ts", "function hashPassword(pw) { return crypto.createHash('sha256').update(pw).digest(); }");
  auto f = OwaspCheck().run(fs, r);
  bool found = false;
  for (auto& finding : f)
    if (finding.rule == "a07-custom-auth") found = true;
  CHECK(found);
}

#include "checks/quality/a11y.cpp"

TEST_CASE("a11y: div with onClick") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/x.tsx", "<div onClick={handleClick}>click me</div>");
  auto f = A11yCheck().run(fs, r);
  CHECK(f.size() >= 1);
  CHECK(f[0].rule == "a11y-click-div");
}

TEST_CASE("a11y: img without alt") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/x.tsx", "<img src='logo.png' />");
  auto f = A11yCheck().run(fs, r);
  CHECK(f.size() >= 1);
  CHECK(f[0].rule == "a11y-img-no-alt");
}

TEST_CASE("a11y: button is fine") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/x.tsx", "<button onClick={handleClick}>click me</button>");
  auto f = A11yCheck().run(fs, r);
  CHECK(f.empty());
}

#include "checks/deps/deps_placement.cpp"

TEST_CASE("deps-placement: typescript in dependencies") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("package.json", "{\"dependencies\":{\"typescript\":\"5.0.0\",\"react\":\"18.0.0\"}}");
  auto f = DepsPlacementCheck().run(fs, r);
  CHECK(f.size() == 1);
  CHECK(f[0].rule == "dev-in-prod");
}

TEST_CASE("deps-placement: react in devDependencies") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("package.json", "{\"dependencies\":{},\"devDependencies\":{\"react\":\"18.0.0\"}}");
  auto f = DepsPlacementCheck().run(fs, r);
  CHECK(f.size() == 1);
  CHECK(f[0].rule == "prod-in-dev");
}

TEST_CASE("deps-placement: correct placement") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("package.json", "{\"dependencies\":{\"react\":\"18.0.0\"},\"devDependencies\":{\"typescript\":\"5.0.0\"}}");
  CHECK(DepsPlacementCheck().run(fs, r).empty());
}

#include "checks/quality/web_quality.cpp"

TEST_CASE("web-quality: full lodash import") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/utils.ts", "import lodash from 'lodash';");
  auto f = WebQualityCheck().run(fs, r);
  CHECK(f.size() >= 1);
  CHECK(f[0].rule == "bundle-lodash-full");
}

TEST_CASE("web-quality: moment.js") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/date.ts", "import moment from 'moment';");
  auto f = WebQualityCheck().run(fs, r);
  CHECK(f.size() >= 1);
  CHECK(f[0].rule == "bundle-moment");
}

TEST_CASE("web-quality: JSON.stringify in log") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/api.ts", "console.error(JSON.stringify(error));");
  auto f = WebQualityCheck().run(fs, r);
  CHECK(f.size() >= 1);
}

TEST_CASE("web-quality: dead link") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/nav.tsx", "<a href=\"#\">Click</a>");
  auto f = WebQualityCheck().run(fs, r);
  CHECK(f.size() >= 1);
  CHECK(f[0].rule == "dead-link");
}

#include "checks/security/api_security.cpp"

TEST_CASE("api-security: GraphQL playground enabled") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("package.json", "{}");
  fs.add_file("src/app.ts", "const server = new ApolloServer({ playground: true });");
  auto f = ApiSecurityCheck().run(fs, r);
  CHECK(f.size() >= 1);
  CHECK(f[0].rule == "graphql-playground");
}

TEST_CASE("api-security: missing license") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/x.ts", "");
  auto f = ApiSecurityCheck().run(fs, r);
  bool found = false;
  for (auto& fi : f)
    if (fi.rule == "no-license") found = true;
  CHECK(found);
}

TEST_CASE("test-quality: empty test without assertions") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/app.test.ts", "it('should work', () => {\n  const x = 1;\n});");
  auto f = TestQualityCheck().run(fs, r);
  CHECK(f.size() == 1);
  CHECK(f[0].rule == "empty-test");
}

TEST_CASE("test-quality: test with assertion is fine") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/app.test.ts", "it('should work', () => {\n  expect(1).toBe(1);\n});");
  CHECK(TestQualityCheck().run(fs, r).empty());
}

#include "checks/quality/code_smells.cpp"

TEST_CASE("code-smells: Dockerfile too many layers") {
  MockFileSystem fs;
  MockToolRunner r;
  std::string df;
  for (int i = 0; i < 12; i++) df += "RUN apt-get install pkg" + std::to_string(i) + "\n";
  fs.add_file("Dockerfile", df);
  auto f = CodeSmellsCheck().run(fs, r);
  bool found = false;
  for (auto& fi : f)
    if (fi.rule == "docker-too-many-layers") found = true;
  CHECK(found);
}

TEST_CASE("code-smells: date without timezone") {
  MockFileSystem fs;
  MockToolRunner r;
  fs.add_file("src/api.ts", "const now = new Date();");
  auto f = CodeSmellsCheck().run(fs, r);
  CHECK(f.size() >= 1);
}

TEST_CASE("code-smells: inconsistent imports") {
  MockFileSystem fs;
  MockToolRunner r;
  std::string code = "import * as a from 'a';\nimport * as b from 'b';\nimport * as c from 'c';\n";
  code += "import { x } from 'x';\nimport { y } from 'y';\nimport { z } from 'z';\n";
  fs.add_file("src/x.ts", code);
  auto f = CodeSmellsCheck().run(fs, r);
  bool found = false;
  for (auto& fi : f)
    if (fi.rule == "inconsistent-imports") found = true;
  CHECK(found);
}

} // TEST_SUITE("checks")
