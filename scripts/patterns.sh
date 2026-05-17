#!/usr/bin/env bash
# scripts/patterns.sh — Detect code patterns and architecture in a codebase
# Usage: bash scripts/patterns.sh [path]
set -o nounset -o pipefail

REPO="${1:-.}"
EXCLUDE="node_modules|\.next|dist|build|\.git|coverage|vendor|target|__pycache__"

FILES=$(find "$REPO" -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
  -o -name "*.cpp" -o -name "*.c" -o -name "*.h" -o -name "*.java" -o -name "*.py" \
  -o -name "*.go" -o -name "*.rs" -o -name "*.cs" 2>/dev/null | grep -vE "$EXCLUDE" || true)
[ -z "$FILES" ] && {
  echo "  No source files found"
  exit 0
}

echo ""
echo "  ■ Detected patterns: $(basename "$(cd "$REPO" && pwd)")"
echo ""

found() { printf "  ✓ %-35s %s\n" "$1" "$2"; }

# === Architecture ===
echo "  Architecture:"

# MVC
echo "$FILES" | grep -qiE "controller|service|repository|model" &&
  found "MVC / Layered" "controller + service + repository detected"

# Feature-based structure
[ -d "$REPO/src/features" ] || [ -d "$REPO/features" ] || [ -d "$REPO/app" ] &&
  find "$REPO" -maxdepth 3 -type d -name "features" 2>/dev/null | head -1 | grep -q . &&
  found "Feature-based structure" "src/features/ or features/ directory"

# Hexagonal / Ports & Adapters
echo "$FILES" | grep -qiE "port|adapter|infrastructure|domain" &&
  found "Hexagonal (Ports & Adapters)" "port/adapter/domain/infrastructure dirs"

# Microservices hints
[ -f "$REPO/docker-compose.yml" ] && grep -q "services:" "$REPO/docker-compose.yml" 2>/dev/null &&
  found "Microservices" "docker-compose with multiple services"

# Monorepo
([ -f "$REPO/nx.json" ] || [ -f "$REPO/lerna.json" ] || [ -d "$REPO/packages" ] || [ -d "$REPO/apps" ]) &&
  found "Monorepo" "nx.json/lerna.json/packages/apps detected"

echo ""
echo "  Design Patterns:"

# Singleton
echo "$FILES" | xargs grep -l "getInstance\|static instance\|private constructor\|providedIn.*root" 2>/dev/null | head -1 | grep -q . &&
  found "Singleton" "getInstance() or private constructor"

# Factory
echo "$FILES" | xargs grep -l "Factory\|createInstance\|factory(" 2>/dev/null | head -1 | grep -q . &&
  found "Factory" "Factory class or create* method"

# Observer / Pub-Sub
echo "$FILES" | xargs grep -l "subscribe\|addEventListener\|EventEmitter\|on(\|emit(" 2>/dev/null | head -1 | grep -q . &&
  found "Observer / Pub-Sub" "subscribe/emit/EventEmitter"

# Strategy
echo "$FILES" | xargs grep -l "Strategy\|strategy\|setStrategy\|algorithm" 2>/dev/null | head -1 | grep -q . &&
  found "Strategy" "Strategy interface or pattern"

# Decorator
echo "$FILES" | xargs grep -l "@Injectable\|@Component\|@Decorator\|@.*(" 2>/dev/null | head -1 | grep -q . &&
  found "Decorator" "@ decorators (Angular/NestJS/Python)"

# Repository pattern
echo "$FILES" | xargs grep -l "Repository\|repository" 2>/dev/null | grep -v "\.git" | head -1 | grep -q . &&
  found "Repository" "Repository class/interface"

# Dependency Injection
echo "$FILES" | xargs grep -l "inject\|@Inject\|constructor.*private.*service\|useInjection\|providedIn" 2>/dev/null | head -1 | grep -q . &&
  found "Dependency Injection" "inject/constructor injection"

# Command pattern / CQRS
echo "$FILES" | xargs grep -l "Command\|Handler\|execute(" 2>/dev/null | head -1 | grep -q . &&
  found "Command / CQRS" "Command + Handler pattern"

# Middleware
echo "$FILES" | xargs grep -l "middleware\|use(\|next(" 2>/dev/null | head -1 | grep -q . &&
  found "Middleware / Pipeline" "middleware chain (Express/Koa style)"

# State management (Redux/NgRx/Zustand)
echo "$FILES" | xargs grep -l "createStore\|createSlice\|useSelector\|dispatch\|@ngrx\|zustand\|signal(" 2>/dev/null | head -1 | grep -q . &&
  found "State Management" "Redux/NgRx/Zustand/Signals"

echo ""
echo "  Principles:"

# Reactive / RxJS
echo "$FILES" | xargs grep -l "Observable\|pipe(\|switchMap\|mergeMap\|BehaviorSubject" 2>/dev/null | head -1 | grep -q . &&
  found "Reactive (RxJS)" "Observable/pipe/operators"

# Functional patterns
echo "$FILES" | xargs grep -l "\.map(\|\.filter(\|\.reduce(\|compose(\|curry(" 2>/dev/null | head -1 | grep -q . &&
  found "Functional Programming" "map/filter/reduce/compose"

# Immutability
echo "$FILES" | xargs grep -l "readonly\|Object\.freeze\|Immutable\|immer\|produce(" 2>/dev/null | head -1 | grep -q . &&
  found "Immutability" "readonly/Object.freeze/immer"

# Event Sourcing
echo "$FILES" | xargs grep -l "EventStore\|eventStore\|append.*event\|replay" 2>/dev/null | head -1 | grep -q . &&
  found "Event Sourcing" "EventStore/append/replay"

# Guard / Route protection
echo "$FILES" | xargs grep -l "canActivate\|authGuard\|ProtectedRoute\|middleware.*auth" 2>/dev/null | head -1 | grep -q . &&
  found "Guard / Route Protection" "canActivate/authGuard/ProtectedRoute"

echo ""
