#!/usr/bin/env bash
# checks/javascript/angular/check-angular-17.sh
# Angular 17 anti-patterns: standalone, unsubscribe, @defer, new control flow, inject
set -o nounset -o pipefail

REPO="${1:-.}"
[ -f "$REPO/package.json" ] && grep -q '"@angular/core"' "$REPO/package.json" || exit 0

findings_add() { printf "  %-8s %-28s %s\n" "$1" "$3" "$4"; }

SRC=""
[ -d "$REPO/src" ] && SRC="$REPO/src/"
[ -d "$REPO/app" ] && SRC="$SRC $REPO/app/"
[ -z "$SRC" ] && exit 0

# No standalone: true on components (legacy modules)
while IFS= read -r file; do
  if grep -qE "@Component\s*\{[^}]*templateUrl" "$file" 2>/dev/null && ! grep -qE "standalone:\s*true" "$file" 2>/dev/null; then
    findings_add "warning" "angular17-no-standalone" "Component without standalone: true" \
      "Angular 17+ uses standalone components. Add standalone: true" \
      "https://angular.io/guide/standalone-components"
  fi
done < <(find $SRC -name "*.ts" 2>/dev/null)

# subscribe() without unsubscribe/takeUntilDestroyed
while IFS= read -r file; do
  if grep -qE "\.subscribe\s*\(" "$file" 2>/dev/null; then
    if ! grep -qE "unsubscribe|takeUntilDestroyed|takeUntil\s*\(" "$file" 2>/dev/null; then
      findings_add "warning" "angular17-no-unsubscribe" "subscribe() without unsubscribe" \
        "Store subscription to unsubscribe in ngOnDestroy or use takeUntilDestroyed()" \
        "https://angular.io/guide/subscription"
    fi
  fi
done < <(find $SRC -name "*.ts" 2>/dev/null)

# No @defer for heavy components
while IFS= read -r file; do
  if grep -qE "large|heavy|complex" "$file" 2>/dev/null && ! grep -qE "@defer" "$file" 2>/dev/null; then
    findings_add "warning" "angular17-no-defer" "No @defer for potentially heavy component" \
      "Use @defer (on viewport) { <HeavyComponent /> } @placeholder { ... }" \
      "https://angular.io/guide/defer"
  fi
done < <(find $SRC -name "*.html" 2>/dev/null)

# *ngIf/*ngFor instead of @if/@for (new control flow)
while IFS= read -r file; do
  if grep -qE "\*ngIf|\*ngFor" "$file" 2>/dev/null; then
    findings_add "warning" "angular17-old-control-flow" "Using *ngIf/*ngFor instead of @if/@for" \
      "Angular 17+ has new control flow: @if (cond) {} @for (item of items) {}" \
      "https://angular.io/guide/control-flow"
  fi
done < <(find $SRC -name "*.html" 2>/dev/null)

# No inject() function (using constructor injection only)
while IFS= read -r file; do
  if grep -qE "constructor\s*\([^)]*private" "$file" 2>/dev/null && ! grep -qE "inject\s*\(" "$file" 2>/dev/null; then
    findings_add "warning" "angular17-no-inject" "Using constructor injection instead of inject()" \
      "Prefer inject() for dependency injection in Angular 17+" \
      "https://angular.io/api/core/inject"
  fi
done < <(find $SRC -name "*.ts" 2>/dev/null)

# Missing OnPush change detection
while IFS= read -r file; do
  if grep -qE "@Component\s*\{[^}]*changeDetection" "$file" 2>/dev/null && ! grep -qE "ChangeDetectionStrategy\.OnPush" "$file" 2>/dev/null; then
    findings_add "warning" "angular17-no-onpush" "Component without OnPush change detection" \
      "Consider OnPush for better performance" \
      "https://angular.io/api/core/ChangeDetectionStrategy"
  fi
done < <(find $SRC -name "*.ts" 2>/dev/null)

# No typed forms (FormControl<string>)
while IFS= read -r file; do
  if grep -qE "FormControl\s*\(\)" "$file" 2>/dev/null && ! grep -qE "FormControl<" "$file" 2>/dev/null; then
    findings_add "warning" "angular17-untyped-form" "Untyped FormControl" \
      "Use typed forms: FormControl<string>(null, { nonNullable: true })" \
      "https://angular.io/guide/typed-forms"
  fi
done < <(find $SRC -name "*.ts" 2>/dev/null)

# BehaviorSubject without signal migration
while IFS= read -r file; do
  if grep -qE "BehaviorSubject" "$file" 2>/dev/null && ! grep -qE "signal\(|toSignal" "$file" 2>/dev/null; then
    findings_add "warning" "angular17-behaviorsubject" "BehaviorSubject without signal migration" \
      "Consider migrating to signals: const count = signal(0)" \
      "https://angular.io/guide/signals"
  fi
done < <(find $SRC -name "*.ts" 2>/dev/null)

# No provideHttpClient() (legacy HttpClientModule)
while IFS= read -r file; do
  if grep -qE "HttpClientModule" "$file" 2>/dev/null; then
    findings_add "warning" "angular17-httpclient-module" "Using HttpClientModule instead of provideHttpClient()" \
      "Use provideHttpClient() with interceptors in app.config.ts" \
      "https://angular.io/api/common/http/provideHttpClient"
  fi
done < <(find $SRC -name "*.ts" 2>/dev/null)

# Template-driven forms in large app (use reactive)
while IFS= read -r file; do
  if grep -qE "NgForm|NgModel" "$file" 2>/dev/null; then
    findings_add "warning" "angular17-template-forms" "Template-driven forms (NgModel/NgForm)" \
      "For large apps, prefer ReactiveForms for better testability and maintainability" \
      "https://angular.io/guide/forms"
  fi
done < <(find $SRC -name "*.ts" 2>/dev/null)

echo "  ✓ Angular 17 patterns checked"