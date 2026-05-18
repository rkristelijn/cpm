#!/usr/bin/env bash
# check-ci-quality.sh — Lint CI/CD configs (GitLab CI, GitHub Actions, Dockerfile, docker-compose)
# Usage: check-ci-quality.sh [repo_path]
# Output: one finding per line: severity|file|rule|message
#
# Design: each check is a function that greps/tests a file and emits findings.
# Easy to extend: add a function, add it to the runner array.

REPO="${1:-.}"
FINDINGS=0

emit() { # severity file rule message
  printf "%s|%s|%s|%s\n" "$1" "$2" "$3" "$4"
  FINDINGS=$((FINDINGS + 1))
}

# ─────────────────────────────────────────────────────────────────────────────
# GITLAB CI CHECKS
# ─────────────────────────────────────────────────────────────────────────────
check_gitlab_ci() {
  local f="$REPO/.gitlab-ci.yml"
  [ -f "$f" ] || return 0
  local c; c=$(cat "$f")

  echo "$c" | grep -q "cache" || \
    emit warning "$f" no-cache "No cache — slow pipelines. See: https://docs.gitlab.com/ci/caching/"
  echo "$c" | grep -q "artifacts" || \
    emit warning "$f" no-artifacts "No artifacts/reports — no JUnit in MR. See: https://docs.gitlab.com/ci/testing/unit_test_reports/"
  echo "$c" | grep -qE "rules|workflow:" || echo "$c" | grep -q "only:" || \
    emit warning "$f" no-rules "No rules/workflow — runs on every push. See: https://docs.gitlab.com/ci/yaml/#rules"
  echo "$c" | grep -q "timeout" || \
    emit warning "$f" no-timeout "No timeout — stuck jobs block runners. See: https://docs.gitlab.com/ci/yaml/#timeout"
  echo "$c" | grep -q "interruptible" || \
    emit warning "$f" no-interruptible "Not interruptible — old pipelines waste minutes. See: https://docs.gitlab.com/ci/yaml/#interruptible"
  echo "$c" | grep -q "allow_failure: true" && \
    emit warning "$f" blanket-allow-failure "allow_failure:true hides failures. See: https://docs.gitlab.com/ci/yaml/#allow_failure"
  echo "$c" | grep -qE "only:|except:" && \
    emit warning "$f" deprecated-only-except "only/except deprecated — use rules:. See: https://docs.gitlab.com/ci/yaml/#only--except"
  echo "$c" | grep -q ":latest" && \
    emit warning "$f" latest-tag "Using :latest — non-reproducible. See: https://docs.gitlab.com/ci/docker/using_docker_images.html"
  echo "$c" | grep -qE "export.*(TOKEN|PASSWORD|SECRET)=" && \
    emit error "$f" hardcoded-secret "Hardcoded secret in script — use CI variables. See: https://docs.gitlab.com/ci/variables/"
  echo "$c" | grep -q "project:" && ! echo "$c" | grep -q "ref:" && \
    emit warning "$f" unpinned-include "include: without ref: — fragile. See: https://docs.gitlab.com/ci/yaml/#includefile"
  echo "$c" | grep -q "git clone" && \
    emit warning "$f" git-clone-in-script "git clone in script — use artifacts/needs:. See: https://docs.gitlab.com/ci/yaml/#needs"
  echo "$c" | grep -q "retry" || \
    emit warning "$f" no-retry "No retry: — flaky jobs fail permanently. See: https://docs.gitlab.com/ci/yaml/#retry"
}

# ─────────────────────────────────────────────────────────────────────────────
# GITHUB ACTIONS CHECKS
# ─────────────────────────────────────────────────────────────────────────────
check_github_actions() {
  local dir="$REPO/.github/workflows"
  [ -d "$dir" ] || return 0

  for f in "$dir"/*.yml "$dir"/*.yaml; do
    [ -f "$f" ] || continue
    local c; c=$(cat "$f")
    local name; name=$(basename "$f")

    echo "$c" | grep -q "permissions" || \
      emit warning "$f" no-permissions "No permissions: — token has full access. See: https://docs.github.com/en/actions/security-guides/automatic-token-authentication"
    echo "$c" | grep -q "concurrency" || \
      emit warning "$f" no-concurrency "No concurrency: — duplicate runs waste minutes. See: https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/control-the-concurrency-of-workflows"
    echo "$c" | grep -q "timeout-minutes" || \
      emit warning "$f" no-timeout "No timeout-minutes — stuck jobs run for 6h. See: https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions#jobsjob_idtimeout-minutes"
    echo "$c" | grep -qE "uses:.*@v[0-9]" && ! echo "$c" | grep -qE "uses:.*@[a-f0-9]{40}" && \
      emit warning "$f" unpinned-actions "Actions pinned to tag not SHA — supply chain risk. See: https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions#using-third-party-actions"
    echo "$c" | grep -q "ubuntu-latest" && \
      emit warning "$f" latest-runner "ubuntu-latest is non-deterministic — pin to ubuntu-24.04. See: https://github.com/actions/runner-images"
    echo "$c" | grep -qE "\\\$\\{\\{.*github\\.(event\\.issue|event\\.pull_request)\\.title" && \
      emit error "$f" injection-risk "Untrusted input in expression — command injection risk. See: https://securitylab.github.com/resources/github-actions-untrusted-input/"
    echo "$c" | grep -q "pull_request_target" && \
      emit warning "$f" pr-target-risk "pull_request_target with checkout — potential secret exposure. See: https://securitylab.github.com/resources/github-actions-preventing-pwn-requests/"
    echo "$c" | grep -q "actions/cache" || echo "$c" | grep -q "cache:" || \
      emit warning "$f" no-cache "No caching — slow builds. See: https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/caching-dependencies-to-speed-up-workflows"
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# DOCKERFILE CHECKS
# ─────────────────────────────────────────────────────────────────────────────
check_dockerfile() {
  for f in "$REPO/Dockerfile" "$REPO"/Dockerfile.*; do
    [ -f "$f" ] || continue
    local c; c=$(cat "$f")

    echo "$c" | grep -qE "^FROM.*:latest" && \
      emit warning "$f" from-latest "FROM :latest — non-reproducible. See: https://docs.docker.com/build/building/best-practices/#pin-base-image-versions"
    echo "$c" | grep -qE "^FROM" | head -1 | grep -qvE ":[a-z0-9]" && \
      emit warning "$f" untagged-base "FROM without tag — defaults to :latest. See: https://docs.docker.com/build/building/best-practices/#pin-base-image-versions"
    echo "$c" | grep -q "USER" || \
      emit warning "$f" no-user "No USER — runs as root. See: https://docs.docker.com/build/building/best-practices/#user"
    echo "$c" | grep -qE "^(RUN|COPY|ADD)" | wc -l | grep -q "^[0-9]$" || true
    echo "$c" | grep -qE "apt-get install" && ! echo "$c" | grep -q "no-install-recommends" && \
      emit warning "$f" no-recommends "apt-get without --no-install-recommends — bloated image. See: https://docs.docker.com/build/building/best-practices/#apt-get"
    echo "$c" | grep -qE "apt-get install" && ! echo "$c" | grep -q "rm -rf /var/lib/apt" && \
      emit warning "$f" apt-cache "apt cache not cleaned — bloated image. See: https://docs.docker.com/build/building/best-practices/#apt-get"
    echo "$c" | grep -q "COPY \. \." && ! [ -f "$REPO/.dockerignore" ] && \
      emit warning "$f" no-dockerignore "COPY . . without .dockerignore — copies everything. See: https://docs.docker.com/build/building/best-practices/#dockerignore"
    echo "$c" | grep -qE "^(ENV|ARG).*(PASSWORD|SECRET|TOKEN|KEY)=" && \
      emit error "$f" secret-in-env "Secret in ENV/ARG — visible in image layers. See: https://docs.docker.com/build/building/secrets/"
    echo "$c" | grep -qE "^EXPOSE" || \
      emit warning "$f" no-expose "No EXPOSE — port undocumented. See: https://docs.docker.com/reference/dockerfile/#expose"
    echo "$c" | grep -qE "^HEALTHCHECK" || \
      emit warning "$f" no-healthcheck "No HEALTHCHECK — orchestrator can't detect failures. See: https://docs.docker.com/reference/dockerfile/#healthcheck"
    echo "$c" | grep -qE "CMD.*&&" && \
      emit warning "$f" cmd-shell-form "CMD with shell form — no signal forwarding. See: https://docs.docker.com/reference/dockerfile/#cmd"
    echo "$c" | grep -qE "^ADD https?://" && \
      emit warning "$f" add-url "ADD with URL — use COPY + curl for caching. See: https://docs.docker.com/build/building/best-practices/#add-or-copy"
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# DOCKER-COMPOSE CHECKS
# ─────────────────────────────────────────────────────────────────────────────
check_docker_compose() {
  local f=""
  [ -f "$REPO/docker-compose.yml" ] && f="$REPO/docker-compose.yml"
  [ -f "$REPO/docker-compose.yaml" ] && f="$REPO/docker-compose.yaml"
  [ -f "$REPO/compose.yml" ] && f="$REPO/compose.yml"
  [ -z "$f" ] && return 0
  local c; c=$(cat "$f")

  echo "$c" | grep -q ":latest" && \
    emit warning "$f" latest-tag "Using :latest in compose — pin versions. See: https://docs.docker.com/compose/how-tos/environment-variables/best-practices/"
  echo "$c" | grep -q "privileged: true" && \
    emit error "$f" privileged "privileged: true — full host access. See: https://docs.docker.com/reference/compose-file/services/#privileged"
  echo "$c" | grep -qE "0\\.0\\.0\\.0:|ports:" && ! echo "$c" | grep -q "127.0.0.1:" && \
    emit warning "$f" exposed-ports "Ports bound to 0.0.0.0 — exposed to network. Bind to 127.0.0.1: for local dev."
  echo "$c" | grep -q "restart" || \
    emit warning "$f" no-restart "No restart policy — containers don't recover from crashes. See: https://docs.docker.com/reference/compose-file/services/#restart"
  echo "$c" | grep -qE "(PASSWORD|SECRET|TOKEN)=" && ! echo "$c" | grep -q "_FILE" && \
    emit error "$f" inline-secret "Secrets inline in compose — use secrets: or env_file. See: https://docs.docker.com/compose/how-tos/use-secrets/"
  echo "$c" | grep -q "mem_limit\|deploy:" || \
    emit warning "$f" no-resource-limits "No resource limits — containers can OOM the host. See: https://docs.docker.com/reference/compose-file/services/#deploy"
}

# ─────────────────────────────────────────────────────────────────────────────
# DOCKER IMAGE AGE/EOL CHECKS (across all CI and Docker files)
# ─────────────────────────────────────────────────────────────────────────────
check_docker_images() {
  # Collect all image references from CI files, Dockerfiles, compose
  local images=""
  for f in "$REPO/.gitlab-ci.yml" "$REPO"/.ci/*.yml "$REPO/.github/workflows"/*.yml "$REPO/.github/workflows"/*.yaml "$REPO/Dockerfile" "$REPO"/Dockerfile.* "$REPO/docker-compose.yml" "$REPO/docker-compose.yaml" "$REPO/compose.yml"; do
    [ -f "$f" ] 2>/dev/null || continue
    local found; found=$(grep -hE "^\s*(image:|FROM|container:)\s*" "$f" 2>/dev/null | sed 's/.*image:\s*//' | sed 's/.*FROM\s*//' | sed 's/.*container:\s*//' | sed 's/\s*AS.*//' | sed 's/#.*//' | grep -v '^\s*$' | grep -v '^\$')
    [ -n "$found" ] && images="$images
$f|$found"
  done
  [ -z "$images" ] && return 0

  echo "$images" | while IFS='|' read -r file img; do
    [ -z "$img" ] && continue
    img=$(echo "$img" | xargs) # trim
    # Skip YAML anchors and variables
    echo "$img" | grep -qE "^[&*\$\{]" && continue

    # No tag at all (implicit :latest)
    echo "$img" | grep -qE ":[a-zA-Z0-9]" || { [ -n "$img" ] && \
      emit warning "$file" untagged-image "Image '$img' has no tag — defaults to :latest. Pin a version."; continue; }

    # Explicit :latest
    echo "$img" | grep -q ":latest" && \
      emit warning "$file" latest-image "Image '$img' uses :latest — non-reproducible builds."

    # EOL Node images (any image containing node:<eol version>)
    echo "$img" | grep -qiE "node[:/](0\.|[4-9][^0-9]|1[0-6][^0-9]|1[0-6]-|1[0-6]$)" && \
      emit error "$file" eol-image "Image '$img' uses EOL Node.js — upgrade to node:20+. See: https://endoflife.date/nodejs"

    # EOL Python images
    echo "$img" | grep -qiE "python[:/](2\.|3\.[0-8][^0-9]|3\.[0-8]$)" && \
      emit error "$file" eol-image "Image '$img' uses EOL Python — upgrade to 3.10+. See: https://endoflife.date/python"

    # EOL PostgreSQL (< 14)
    echo "$img" | grep -qiE "postgres[:/](9\.|1[0-3][^0-9]|1[0-3]$)" && \
      emit warning "$file" eol-image "Image '$img' uses EOL PostgreSQL — upgrade to 15+. See: https://endoflife.date/postgresql"

    # EOL/deprecated OpenJDK
    echo "$img" | grep -qiE "openjdk[:/](8|11|1[0-6])" && \
      emit warning "$file" eol-image "Image '$img' uses deprecated OpenJDK — use eclipse-temurin:21+. See: https://endoflife.date/java"

    # EOL MySQL (< 8.0)
    echo "$img" | grep -qiE "mysql[:/][5-7]\." && \
      emit warning "$file" eol-image "Image '$img' uses EOL MySQL — upgrade to 8.0+. See: https://endoflife.date/mysql"

    # EOL Alpine (< 3.18)
    echo "$img" | grep -qiE "alpine[:/](3\.[0-9][^0-9]|3\.1[0-7][^0-9])" && \
      emit warning "$file" old-image "Image '$img' uses old Alpine — consider 3.20+. See: https://endoflife.date/alpine"

    # Deprecated circleci images
    echo "$img" | grep -qi "circleci/" && \
      emit warning "$file" deprecated-image "Image '$img' — circleci/ images are deprecated, use cimg/. See: https://circleci.com/docs/next-gen-migration-guide/"
  done
}

# ─────────────────────────────────────────────────────────────────────────────
# RUN ALL CHECKS
# ─────────────────────────────────────────────────────────────────────────────
check_gitlab_ci
check_github_actions
check_dockerfile
check_docker_compose
check_docker_images

exit $( [ "$FINDINGS" -eq 0 ] && echo 0 || echo 1 )
