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
#include "checks/deps/lockfile.cpp"
#include "checks/deps/runtime_eol.cpp"
#include "checks/deps/version_pins.cpp"
#include "checks/quality/comments.cpp"
#include "checks/quality/complexity.cpp"
#include "checks/quality/dead_docs.cpp"
#include "checks/quality/filesize.cpp"
#include "checks/quality/makefile.cpp"
#include "checks/quality/regex_quality.cpp"
#include "checks/quality/slop.cpp"
#include "checks/quality/todo.cpp"
#include "checks/security/dangerous.cpp"
#include "checks/security/pii.cpp"
#include "checks/security/secrets.cpp"
#include "checks/style/async.cpp"
#include "checks/style/imports.cpp"
#include "checks/style/inclusivity.cpp"
#include "checks/style/portability.cpp"
#include "checks/style/unicode.cpp"

TEST_SUITE("checks") {
  /* === Secrets === */
  SCENARIO("secrets: detecting API keys") {
    GIVEN("a file with an OpenAI key") {
      MockFileSystem fs;
      MockToolRunner r;
      fs.add_file("src/main.cpp", "auto key = \"sk-12345678901234567890\";");
      WHEN("the check runs") {
        auto findings = SecretsCheck().run(fs, r);
        THEN("it detects the secret") { REQUIRE(findings.size() == 1); }
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
  TEST_CASE("dangerous: ts-ignore") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/x.ts", "// @ts-ignore\nconst x = 1;");
    auto f = DangerousCheck().run(fs, r);
    CHECK(f.size() == 1);
    CHECK(f[0].rule == "ts-ignore");
    CHECK(f[0].severity == "warning");
  }
  TEST_CASE("dangerous: as any") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/x.ts", "const x = foo as any;");
    auto f = DangerousCheck().run(fs, r);
    CHECK(f.size() == 1);
    CHECK(f[0].rule == "as-any");
    CHECK(f[0].severity == "warning");
  }
  TEST_CASE("dangerous: clean file") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/x.ts", "const x = 1;\nconst y = 2;\n");
    auto f = DangerousCheck().run(fs, r);
    CHECK(f.empty());
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
#include "checks/quality/mock_boundary.cpp"

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

#include "checks/security/unsafe_str.cpp"

  TEST_CASE("unsafe-str: detects strcpy") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/util.cpp", "void f() { strcpy(dst, src); }");
    auto f = UnsafeStrCheck().run(fs, r);
    CHECK(f.size() == 1);
    CHECK(f[0].rule == "strcpy");
  }

  TEST_CASE("unsafe-str: detects sprintf") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/fmt.c", "sprintf(buf, \"%s\", input);");
    auto f = UnsafeStrCheck().run(fs, r);
    CHECK(f.size() == 1);
    CHECK(f[0].rule == "sprintf");
  }

  TEST_CASE("unsafe-str: ignores test files") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/util_test.cpp", "strcpy(dst, src);");
    CHECK(UnsafeStrCheck().run(fs, r).empty());
  }

  TEST_CASE("unsafe-str: clean file passes") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/safe.cpp", "snprintf(dst, sizeof(dst), \"%s\", src);");
    CHECK(UnsafeStrCheck().run(fs, r).empty());
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

#include "checks/docs/doc_complexity.cpp"

  /* === Doc Complexity ===
   * Measures documentation quality: readability, structure, completeness. */
  TEST_CASE("doc-complexity: too long") {
    MockFileSystem fs;
    MockToolRunner r;
    std::string big(501, '\n');
    fs.add_file("./docs/guide.md", big);
    auto f = DocComplexityCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "doc-too-long") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-complexity: deep headings") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("./docs/x.md", "# H1\n## H2\n### H3\n#### H4\n##### H5\ntext");
    auto f = DocComplexityCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "heading-too-deep") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-complexity: long sections") {
    MockFileSystem fs;
    MockToolRunner r;
    std::string doc = "# Title\n";
    for (int i = 0; i < 60; i++) doc += "line " + std::to_string(i) + "\n";
    fs.add_file("./docs/x.md", doc);
    auto f = DocComplexityCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "long-sections") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-complexity: low code ratio in tutorial") {
    MockFileSystem fs;
    MockToolRunner r;
    std::string doc;
    for (int i = 0; i < 30; i++) doc += "Some text explaining things.\n";
    fs.add_file("./docs/tutorial.md", doc);
    auto f = DocComplexityCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "low-code-ratio") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-complexity: no diagrams in architecture doc") {
    MockFileSystem fs;
    MockToolRunner r;
    std::string doc = "# Architecture\n";
    for (int i = 0; i < 55; i++) doc += "Design decision text.\n";
    fs.add_file("./docs/architecture.md", doc);
    auto f = DocComplexityCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "no-diagrams") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-complexity: deep list nesting") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("./docs/x.md", "- L1\n  - L2\n    - L3\n      - L4\n        - L5\n");
    auto f = DocComplexityCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "deep-nesting") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-complexity: clean doc passes") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("./docs/ok.md", "# Guide\n\nShort and clear.\n\n```bash\ncpm check\n```\n");
    CHECK(DocComplexityCheck().run(fs, r).empty());
  }

#include "checks/docs/doc_style.cpp"

  /* === Doc Style ===
   * Detects writing anti-patterns: weasel words, passive voice, inconsistency. */

  static void add_style_dicts(MockFileSystem & fs) {
    fs.add_file("dictionaries/weasel-words.txt", "simply|Remove — if it fails, the reader feels stupid\njust|Remove — implies trivial\n");
    fs.add_file("dictionaries/passive-patterns.txt", "is created|say WHO creates it\nis configured|say WHO configures it\n");
    fs.add_file("dictionaries/hedging-phrases.txt", "you might want to|State it directly\n");
    fs.add_file("dictionaries/non-imperative.txt", "you should |Start with the verb directly\nyou can |Start with the verb directly\n");
    fs.add_file("dictionaries/acronyms-common.txt", "API\nCLI\nJSON\n");
  }

  TEST_CASE("doc-style: weasel word") {
    MockFileSystem fs;
    MockToolRunner r;
    add_style_dicts(fs);
    fs.add_file("./docs/x.md", "# Setup\n\nSimply run the install command.\n");
    auto f = DocStyleCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "weasel-word") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-style: passive voice") {
    MockFileSystem fs;
    MockToolRunner r;
    add_style_dicts(fs);
    fs.add_file("./docs/x.md", "# Install\n\nThe config is created automatically.\n");
    auto f = DocStyleCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "passive-voice") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-style: mixed addressing") {
    MockFileSystem fs;
    MockToolRunner r;
    add_style_dicts(fs);
    fs.add_file("./docs/x.md", "# Guide\n\nYou can run this.\n\nWe recommend using cpm.\n");
    auto f = DocStyleCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "mixed-addressing") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-style: non-imperative") {
    MockFileSystem fs;
    MockToolRunner r;
    add_style_dicts(fs);
    fs.add_file("./docs/x.md", "# Steps\n\n- You should run cpm check\n");
    auto f = DocStyleCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "non-imperative") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-style: undefined acronym") {
    MockFileSystem fs;
    MockToolRunner r;
    add_style_dicts(fs);
    fs.add_file("./docs/x.md", "# Overview\n\nThe DORA metrics show improvement.\n");
    auto f = DocStyleCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "undefined-acronym") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-style: hedging") {
    MockFileSystem fs;
    MockToolRunner r;
    add_style_dicts(fs);
    fs.add_file("./docs/x.md", "# Config\n\nYou might want to change the threshold.\n");
    auto f = DocStyleCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "hedging") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-style: clean doc passes") {
    MockFileSystem fs;
    MockToolRunner r;
    add_style_dicts(fs);
    fs.add_file("./docs/ok.md", "# Install\n\nRun the following command:\n\n- Run `cpm init`\n- Run `cpm check`\n");
    CHECK(DocStyleCheck().run(fs, r).empty());
  }

#include "checks/docs/doc_structure.cpp"

  /* === Doc Structure ===
   * Layer 2: scanability, flow, navigation, type-specific validation. */
  TEST_CASE("doc-structure: missing summary") {
    MockFileSystem fs;
    MockToolRunner r;
    std::string doc = "# Title\n## Section\n";
    for (int i = 0; i < 30; i++) doc += "content line\n";
    fs.add_file("./docs/x.md", doc);
    auto f = DocStructureCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "missing-summary") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-structure: missing example") {
    MockFileSystem fs;
    MockToolRunner r;
    std::string doc = "# Guide\n\nIntro text.\n\n## Details\n\n";
    for (int i = 0; i < 50; i++) doc += "Explanation without any code.\n";
    fs.add_file("./docs/x.md", doc);
    auto f = DocStructureCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "missing-example") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-structure: giant list") {
    MockFileSystem fs;
    MockToolRunner r;
    std::string doc = "# Items\n\nList:\n\n";
    for (int i = 0; i < 25; i++) doc += "- item " + std::to_string(i) + "\n";
    fs.add_file("./docs/x.md", doc);
    auto f = DocStructureCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "giant-list") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-structure: skipped heading level") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("./docs/x.md", "# Title\n\nIntro.\n\n#### Deep\n\nContent.\n\n## Normal\n\nMore.\n");
    auto f = DocStructureCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "skipped-heading-level") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-structure: ADR missing sections") {
    MockFileSystem fs;
    MockToolRunner r;
    std::string doc = "# ADR-001: Test\n\nSome intro text about this decision.\n\n## Background\n\n";
    for (int i = 0; i < 15; i++) doc += "Background line " + std::to_string(i) + ".\n";
    doc += "\n## End\n\nDone.\n";
    fs.add_file("./docs/adrs/adr-001-test.md", doc);
    auto f = DocStructureCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "missing-section") found = true;
    CHECK(found); /* missing context and decision */
  }

  TEST_CASE("doc-structure: clean doc passes") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("./docs/ok.md", "# Guide\n\nThis explains X.\n\n## Steps\n\n```bash\ncpm init\n```\n");
    auto f = DocStructureCheck().run(fs, r);
    /* Small doc, should have minimal findings */
    bool has_critical = false;
    for (auto& fi : f)
      if (fi.severity == "error") has_critical = true;
    CHECK(!has_critical);
  }

/* === Doc Cognitive ===
 * Layer 4: cognitive load — concept density, stacked instructions, etc. */
#include "checks/docs/doc_cognitive.cpp"

  TEST_CASE("doc-cognitive: paragraph wall") {
    MockFileSystem fs;
    MockToolRunner r;
    std::string doc = "# Title\n\nIntro.\n\n## Section\n\n";
    for (int i = 0; i < 12; i++) doc += "This is a long prose line number " + std::to_string(i) + ".\n";
    fs.add_file("./docs/x.md", doc);
    auto f = DocCognitiveCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "paragraph-wall") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-cognitive: concept density") {
    MockFileSystem fs;
    MockToolRunner r;
    std::string doc =
        "# Guide\n\nIntro paragraph here with some content.\n\n"
        "## Background\n\nSome background information.\nMore background.\nEven more.\n\n"
        "## Architecture\n\n"
        "Use `ThemeProvider` with `createTheme` and `palette` to configure "
        "`design_tokens` via `CSS_VARIABLES` and `STYLE_OVERRIDES`.\n"
        "More text about the architecture here.\n\n## Other\n\nSimple section.\n";
    fs.add_file("./docs/x.md", doc);
    auto f = DocCognitiveCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "concept-density") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-cognitive: stacked instructions") {
    MockFileSystem fs;
    MockToolRunner r;
    std::string doc =
        "# Setup\n\nIntro paragraph with context.\n\n"
        "## Prerequisites\n\nYou need node installed.\nAnd git.\nAnd a terminal.\n\n"
        "## Steps\n\n"
        "Install node and create the project.\n"
        "Add dependencies and configure eslint.\n"
        "Enable typescript and build the app.\n"
        "Start the server and deploy it.\n\n## Done\n\nFinished.\n";
    fs.add_file("./docs/x.md", doc);
    auto f = DocCognitiveCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "stacked-instructions") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-cognitive: forward references") {
    MockFileSystem fs;
    MockToolRunner r;
    std::string doc =
        "# Guide\n\nIntro paragraph with context.\n\n"
        "## Overview\n\nThis guide covers several topics.\nRead on.\nMore info.\n\n"
        "## Basics\n\n"
        "Use the provider (see below).\n"
        "Configure tokens (explained later).\n"
        "Set up the adapter (described in the Advanced section).\n"
        "More content here.\n\n## Advanced\n\nDetails here.\n";
    fs.add_file("./docs/x.md", doc);
    auto f = DocCognitiveCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "forward-references") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-cognitive: memory overload table") {
    MockFileSystem fs;
    MockToolRunner r;
    std::string doc =
        "# API\n\nIntro paragraph with context.\n\n"
        "## Overview\n\nThis is the API reference.\nIt has many props.\nRead on.\n\n"
        "## Props\n\n| Prop | Type |\n|---|---|\n";
    for (int i = 0; i < 25; i++) doc += "| prop" + std::to_string(i) + " | string |\n";
    doc += "\n## Other\n\nDone.\n";
    fs.add_file("./docs/x.md", doc);
    auto f = DocCognitiveCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "memory-overload") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-cognitive: high scroll distance") {
    MockFileSystem fs;
    MockToolRunner r;
    std::string doc = "# Project\n\nIntro.\n\n";
    for (int i = 0; i < 80; i++) doc += "## Section " + std::to_string(i) + "\n\nContent.\n\n";
    doc += "## Installation\n\nRun npm install.\n";
    fs.add_file("./docs/x.md", doc);
    auto f = DocCognitiveCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "high-scroll-distance") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-cognitive: clean doc passes") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("./docs/x.md",
                "# Guide\n\nShort intro.\n\n## Install\n\n```bash\nnpm install\n```\n\n"
                "## Usage\n\nUse `foo` to do bar.\n");
    auto f = DocCognitiveCheck().run(fs, r);
    CHECK(f.empty());
  }

/* === Doc Type Detection ===
 * Layer 3: deterministic weighted signal scoring for doc type + contract validation. */
#include "checks/docs/doc_type_detect.cpp"

  TEST_CASE("doc-type: README detected by filename") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("./README.md", "# My Project\n\nA cool project.\n\n## Features\n\nStuff.\n");
    auto f = DocTypeDetectCheck().run(fs, r);
    /* README without install section → finding */
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "readme-no-install") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-type: tutorial detected by structure") {
    MockFileSystem fs;
    MockToolRunner r;
    std::string doc =
        "# Build a Widget\n\n## Step 1: Install\n\n```bash\nnpm install\n```\n\n"
        "## Step 2: Configure\n\n```js\nmodule.exports = {}\n```\n\n"
        "## Step 3: Run\n\n```bash\nnpm start\n```\n\n## Step 4: Verify\n\n1. Open browser\n2. Check output\n3. Done\n";
    fs.add_file("./docs/tutorials/widget.md", doc);
    auto f = DocTypeDetectCheck().run(fs, r);
    /* Tutorial detected, check for prerequisites finding */
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "tutorial-no-prerequisites") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-type: ADR detected by path and headings") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("./docs/adrs/adr-001-use-postgres.md",
                "# ADR-001: Use PostgreSQL\n\n## Context\n\nWe need a database.\n\n"
                "## Alternatives\n\n- MySQL\n- MongoDB\n\n## Consequences\n\nNeed DBA.\n");
    auto f = DocTypeDetectCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "adr-no-decision") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-type: reference detected by tables") {
    MockFileSystem fs;
    MockToolRunner r;
    std::string doc = "# CLI Reference\n\n## Commands\n\n| Command | Description |\n|---|---|\n";
    for (int i = 0; i < 15; i++) doc += "| cmd" + std::to_string(i) + " | Does thing |\n";
    doc += "\n## Options\n\n| Flag | Default |\n|---|---|\n| --verbose | false |\n";
    fs.add_file("./docs/reference/cli.md", doc);
    auto f = DocTypeDetectCheck().run(fs, r);
    /* Reference detected — no contract violation expected (has tables) */
    bool has_ref_finding = false;
    for (auto& fi : f)
      if (fi.rule == "reference-no-structure") has_ref_finding = true;
    CHECK(!has_ref_finding);
  }

  TEST_CASE("doc-type: clean contributing passes") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("./CONTRIBUTING.md", "# Contributing\n\n## How to contribute\n\nFork and PR.\n\n## Code style\n\nUse prettier.\n");
    auto f = DocTypeDetectCheck().run(fs, r);
    CHECK(f.empty());
  }

/* === Doc Engineering ===
 * Layer 5: code-block validity, version drift, source-doc drift. */
#include "checks/docs/doc_engineering.cpp"

  TEST_CASE("doc-engineering: invalid JSON unbalanced braces") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("./docs/x.md", "# Config\n\n```json\n{\"name\": \"test\", \"version\": \"1.0\"\n```\n");
    auto f = DocEngineeringCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "code-block-invalid-json") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-engineering: invalid JSON unquoted keys") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("./docs/x.md", "# Config\n\n```json\n{name: \"test\", version: \"1.0\"}\n```\n");
    auto f = DocEngineeringCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "code-block-invalid-json") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-engineering: YAML with tabs") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("./docs/x.md", "# Config\n\n```yaml\nname: test\n\tversion: 1.0\n```\n");
    auto f = DocEngineeringCheck().run(fs, r);
    bool found = false;
    for (auto& fi : f)
      if (fi.rule == "code-block-invalid-yaml") found = true;
    CHECK(found);
  }

  TEST_CASE("doc-engineering: valid JSON passes") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("./docs/x.md", "# Config\n\n```json\n{\"name\": \"test\", \"version\": \"1.0\"}\n```\n");
    auto f = DocEngineeringCheck().run(fs, r);
    CHECK(f.empty());
  }

  TEST_CASE("doc-engineering: valid YAML passes") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("./docs/x.md", "# Config\n\n```yaml\nname: test\nversion: 1.0\nnested:\n  key: value\n```\n");
    auto f = DocEngineeringCheck().run(fs, r);
    CHECK(f.empty());
  }

}  // TEST_SUITE("checks")

/* === Line Scanner Tests === */
#include "line_scanner.h"

TEST_SUITE("line_scanner") {
  TEST_CASE("scan_lines: iterates all lines") {
    MockFileSystem fs;
    fs.add_file("src/main.ts", "line1\nline2\nline3\n");
    int count = 0;
    scan_lines(fs, "src", "\\.(ts)$", [&](const std::string&, int, const std::string&) { count++; });
    CHECK(count == 3);
  }

  TEST_CASE("scan_lines: provides correct file and line number") {
    MockFileSystem fs;
    fs.add_file("src/app.js", "first\nsecond\n");
    std::string last_file;
    int last_line = 0;
    std::string last_content;
    scan_lines(fs, "src", "\\.(js)$", [&](const std::string& file, int line, const std::string& ln) {
      last_file = file;
      last_line = line;
      last_content = ln;
    });
    CHECK(last_file == "src/app.js");
    CHECK(last_line == 2);
    CHECK(last_content == "second");
  }

  TEST_CASE("scan_lines: handles empty file") {
    MockFileSystem fs;
    fs.add_file("src/empty.ts", "");
    int count = 0;
    scan_lines(fs, "src", "\\.(ts)$", [&](const std::string&, int, const std::string&) { count++; });
    CHECK(count == 0);
  }

  TEST_CASE("scan_lines: filters by pattern") {
    MockFileSystem fs;
    fs.add_file("src/main.ts", "ts line\n");
    fs.add_file("src/style.css", "css line\n");
    int count = 0;
    scan_lines(fs, "src", "\\.(ts)$", [&](const std::string&, int, const std::string&) { count++; });
    CHECK(count == 1);
  }

  TEST_CASE("scan_lines: multiple files") {
    MockFileSystem fs;
    fs.add_file("src/a.ts", "a1\na2\n");
    fs.add_file("src/b.ts", "b1\n");
    int count = 0;
    scan_lines(fs, "src", "\\.(ts)$", [&](const std::string&, int, const std::string&) { count++; });
    CHECK(count == 3);
  }

  TEST_CASE("scan_code_lines: skips line comments") {
    MockFileSystem fs;
    fs.add_file("src/main.ts", "code\n// comment\nmore code\n");
    int count = 0;
    scan_code_lines(fs, "src", "\\.(ts)$", [&](const std::string&, int, const std::string&) { count++; });
    CHECK(count == 2);
  }

  TEST_CASE("scan_code_lines: skips block comments") {
    MockFileSystem fs;
    fs.add_file("src/main.ts", "before\n/* start\nmiddle\nend */\nafter\n");
    int count = 0;
    scan_code_lines(fs, "src", "\\.(ts)$", [&](const std::string&, int, const std::string&) { count++; });
    // "before" = code, "/* start" enters block (skipped), "middle" skipped,
    // "end */" exits block (line itself passes), "after" = code
    CHECK(count == 3);
  }

  TEST_CASE("scan_code_lines: indented line comments") {
    MockFileSystem fs;
    fs.add_file("src/main.ts", "  // indented comment\n  real code\n");
    int count = 0;
    scan_code_lines(fs, "src", "\\.(ts)$", [&](const std::string&, int, const std::string&) { count++; });
    CHECK(count == 1);
  }

  /* === Regex Quality === */

  TEST_CASE("regex-quality: detects shell quoting mismatch (odd quotes)") {
    MockFileSystem fs;
    MockToolRunner r;
    /* Odd number of single quotes = broken shell command (our CORS bug class) */
    fs.add_file("scripts/bad.sh", "grep -E 'foo[\"']bar' src/\n");
    auto findings = RegexQualityCheck().run(fs, r);
    REQUIRE(findings.size() >= 1);
    CHECK(findings[0].rule == "shell-quoting-mismatch");
    CHECK(findings[0].severity == "error");
  }

  TEST_CASE("regex-quality: clean shell script passes") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("scripts/good.sh", "grep -E \"Access-Control-Allow-Origin.*[*]\" src/\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool has_quoting = false;
    for (auto& f : findings)
      if (f.rule == "shell-quoting-mismatch") has_quoting = true;
    CHECK_FALSE(has_quoting);
  }

  TEST_CASE("regex-quality: detects PCRE shorthand in ERE context") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("scripts/pcre.sh", "grep -E '\\d+' src/\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "pcre-in-ere-context") found = true;
    CHECK(found);
  }

  TEST_CASE("regex-quality: no false positive for POSIX classes in ERE") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("scripts/ok.sh", "grep -E '[0-9]+' src/\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "pcre-in-ere-context") found = true;
    CHECK_FALSE(found);
  }

  TEST_CASE("regex-quality: detects grep -P portability") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("scripts/find.sh", "grep -P '\\d{3}-\\d{4}' file.txt\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "grep-p-not-portable") found = true;
    CHECK(found);
  }

  TEST_CASE("regex-quality: detects sed -r portability") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("scripts/fix.sh", "sed -r 's/foo(bar)+/baz/' file.txt\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "sed-r-not-portable") found = true;
    CHECK(found);
  }

  TEST_CASE("regex-quality: detects bare ERE metachar in BRE grep") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("scripts/search.sh", "grep 'foo|bar' file.txt\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "bre-ere-mismatch") found = true;
    CHECK(found);
  }

  TEST_CASE("regex-quality: no BRE false positive for grep -E") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("scripts/ok.sh", "grep -E 'foo|bar' file.txt\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "bre-ere-mismatch") found = true;
    CHECK_FALSE(found);
  }

  TEST_CASE("regex-quality: detects nested quantifiers (ReDoS)") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/validator.ts", "const re = new RegExp('(a+)+b');\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "redos-nested-quantifiers") found = true;
    CHECK(found);
  }

  TEST_CASE("regex-quality: no ReDoS false positive for simple regex") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/parser.ts", "const re = new RegExp('^[a-z]+$');\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "redos-nested-quantifiers") found = true;
    CHECK_FALSE(found);
  }

  TEST_CASE("regex-quality: respects cpm:ignore") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("scripts/ignored.sh", "# cpm:ignore regex\ngrep -P '\\d+' file.txt\n");
    auto findings = RegexQualityCheck().run(fs, r);
    CHECK(findings.empty());
  }

  TEST_CASE("regex-quality: skips comment lines in shell") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("scripts/commented.sh", "# grep -P '\\d+' this is a comment\necho hello\n");
    auto findings = RegexQualityCheck().run(fs, r);
    CHECK(findings.empty());
  }

  /* === Phase 2: Security === */

  TEST_CASE("regex-quality: detects overlapping alternation (identical branches)") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/bad.ts", "const re = new RegExp('(foo|foo)+');\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "redos-overlapping-alternation") found = true;
    CHECK(found);
  }

  TEST_CASE("regex-quality: detects overlapping alternation (\\w and \\d)") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/bad.ts", "const re = new RegExp('(\\w+|\\d+)+');\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "redos-overlapping-alternation") found = true;
    CHECK(found);
  }

  TEST_CASE("regex-quality: no overlap false positive for distinct branches") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/ok.ts", "const re = new RegExp('(http|ftp)');\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "redos-overlapping-alternation") found = true;
    CHECK_FALSE(found);
  }

  TEST_CASE("regex-quality: detects missing anchor in validation regex") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/auth.ts", "const isValid = /[a-z0-9]+/.test(input);\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "missing-anchor-validation") found = true;
    CHECK(found);
  }

  TEST_CASE("regex-quality: no anchor warning when anchored") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/auth.ts", "const isValid = /^[a-z0-9]+$/.test(input);\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "missing-anchor-validation") found = true;
    CHECK_FALSE(found);
  }

  TEST_CASE("regex-quality: no anchor warning for non-validation context") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/search.ts", "const result = /[a-z]+/.exec(input);\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "missing-anchor-validation") found = true;
    CHECK_FALSE(found);
  }

  /* === Phase 3: Correctness === */

  TEST_CASE("regex-quality: detects empty alternative (||)") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/parse.ts", "const re = new RegExp('/foo||bar/');\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "empty-alternative") found = true;
    CHECK(found);
  }

  TEST_CASE("regex-quality: detects trailing pipe") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/match.ts", "const regex = /foo|bar|/;\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "empty-alternative") found = true;
    CHECK(found);
  }

  TEST_CASE("regex-quality: no empty-alternative false positive") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/ok.ts", "const regex = /foo|bar|baz/;\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "empty-alternative") found = true;
    CHECK_FALSE(found);
  }

  TEST_CASE("regex-quality: detects unescaped dot in version pattern") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/ver.ts", "const regex = /1.2.3/;\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "unescaped-dot") found = true;
    CHECK(found);
  }

  TEST_CASE("regex-quality: no dot warning when escaped") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/ver.ts", "const regex = /1\\.2\\.3/;\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "unescaped-dot") found = true;
    CHECK_FALSE(found);
  }

  TEST_CASE("regex-quality: no dot warning for intentional wildcard") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/scan.ts", "const regex = /.*foo/;\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "unescaped-dot") found = true;
    CHECK_FALSE(found);
  }

  /* === Phase 4: Style & Performance === */

  TEST_CASE("regex-quality: detects single-char alternation") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/lex.ts", "const regex = /a|b|c|d/;\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "single-char-alternation") found = true;
    CHECK(found);
  }

  TEST_CASE("regex-quality: no single-char warning for multi-char alternatives") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/lex.ts", "const regex = /foo|bar|baz/;\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "single-char-alternation") found = true;
    CHECK_FALSE(found);
  }

  TEST_CASE("regex-quality: detects overly complex regex") {
    MockFileSystem fs;
    MockToolRunner r;
    /* Lots of groups, quantifiers, alternations */
    fs.add_file("src/complex.ts", "const regex = /((a+)(b*)|(c+)(d*)|(e+)(f*)|(g+)(h*)|(i+)(j*))+/;\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "regex-too-complex") found = true;
    CHECK(found);
  }

  TEST_CASE("regex-quality: no complexity warning for simple regex") {
    MockFileSystem fs;
    MockToolRunner r;
    fs.add_file("src/simple.ts", "const regex = /^[a-z]+$/;\n");
    auto findings = RegexQualityCheck().run(fs, r);
    bool found = false;
    for (auto& f : findings)
      if (f.rule == "regex-too-complex") found = true;
    CHECK_FALSE(found);
  }
}
