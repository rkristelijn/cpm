#!/usr/bin/env bash
# scripts/setup-tools.sh — Install language runtimes and analysis tools for deep analysis
# Usage: bash scripts/setup-tools.sh [--all | --php | --node | --java | --python]
set -o nounset -o pipefail

INSTALL_ALL=false
INSTALL_PHP=false
INSTALL_NODE=false
INSTALL_JAVA=false
INSTALL_PYTHON=false

for arg in "$@"; do
  case "$arg" in
    --all) INSTALL_ALL=true ;;
    --php) INSTALL_PHP=true ;;
    --node) INSTALL_NODE=true ;;
    --java) INSTALL_JAVA=true ;;
    --python) INSTALL_PYTHON=true ;;
  esac
done
[ "$INSTALL_ALL" = true ] && INSTALL_PHP=true && INSTALL_NODE=true && INSTALL_JAVA=true && INSTALL_PYTHON=true

# Default to all if nothing specified
[ "$INSTALL_PHP" = false ] && [ "$INSTALL_NODE" = false ] && [ "$INSTALL_JAVA" = false ] && [ "$INSTALL_PYTHON" = false ] && INSTALL_ALL=true && INSTALL_PHP=true && INSTALL_NODE=true && INSTALL_JAVA=true && INSTALL_PYTHON=true

echo ""
echo "  ╔═══════════════════════════════════════════════════╗"
echo "  ║   cpm setup-tools — install analysis runtimes     ║"
echo "  ╚═══════════════════════════════════════════════════╝"
echo ""

# === PHP + analysis tools ===
if [ "$INSTALL_PHP" = true ]; then
  echo "  ■ PHP"
  if command -v php >/dev/null 2>&1; then
    echo "    ✓ php $(php -v | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
  else
    echo "    Installing PHP..."
    if command -v brew >/dev/null 2>&1; then
      brew install php 2>&1 | tail -1
    elif command -v apt-get >/dev/null 2>&1; then
      sudo apt-get install -y php-cli php-mbstring php-xml 2>&1 | tail -1
    fi
  fi
  # PHPStan
  if [ ! -f "$HOME/.local/bin/phpstan" ]; then
    echo "    Installing PHPStan..."
    mkdir -p "$HOME/.local/bin"
    curl -sL https://github.com/phpstan/phpstan/releases/latest/download/phpstan.phar -o "$HOME/.local/bin/phpstan"
    chmod +x "$HOME/.local/bin/phpstan"
  fi
  command -v phpstan >/dev/null 2>&1 || [ -f "$HOME/.local/bin/phpstan" ] && echo "    ✓ phpstan"
  # Psalm
  if [ ! -f "$HOME/.local/bin/psalm" ]; then
    echo "    Installing Psalm..."
    curl -sL https://github.com/vimeo/psalm/releases/latest/download/psalm.phar -o "$HOME/.local/bin/psalm" 2>/dev/null
    chmod +x "$HOME/.local/bin/psalm" 2>/dev/null
  fi
  [ -f "$HOME/.local/bin/psalm" ] && echo "    ✓ psalm"
  # PHP-CS-Fixer
  if [ ! -f "$HOME/.local/bin/php-cs-fixer" ]; then
    echo "    Installing PHP-CS-Fixer..."
    curl -sL https://github.com/PHP-CS-Fixer/PHP-CS-Fixer/releases/latest/download/php-cs-fixer.phar -o "$HOME/.local/bin/php-cs-fixer" 2>/dev/null
    chmod +x "$HOME/.local/bin/php-cs-fixer" 2>/dev/null
  fi
  [ -f "$HOME/.local/bin/php-cs-fixer" ] && echo "    ✓ php-cs-fixer"
  echo ""
fi

# === Node.js + analysis tools ===
if [ "$INSTALL_NODE" = true ]; then
  echo "  ■ Node.js"
  if command -v node >/dev/null 2>&1; then
    echo "    ✓ node $(node -v)"
  else
    echo "    Installing Node.js via nvm..."
    if [ ! -d "$HOME/.nvm" ]; then
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash 2>&1 | tail -1
    fi
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
    nvm install --lts 2>&1 | tail -1
  fi
  # npx tools are auto-installed, just verify npm
  command -v npm >/dev/null 2>&1 && echo "    ✓ npm $(npm -v)" && echo "    ✓ npx (madge, knip, depcheck, jscpd, cost-of-modules — via npx)"
  echo ""
fi

# === Java + analysis tools ===
if [ "$INSTALL_JAVA" = true ]; then
  echo "  ■ Java"
  if command -v java >/dev/null 2>&1; then
    echo "    ✓ java $(java -version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)"
  else
    echo "    Installing Java via sdkman..."
    if [ ! -d "$HOME/.sdkman" ]; then
      curl -s "https://get.sdkman.io" | bash 2>&1 | tail -1
    fi
    source "$HOME/.sdkman/bin/sdkman-init.sh" 2>/dev/null
    sdk install java 2>&1 | tail -1
  fi
  # SpotBugs (static analysis)
  if ! command -v spotbugs >/dev/null 2>&1; then
    echo "    Note: Install SpotBugs via: sdk install spotbugs (or brew install spotbugs)"
  fi
  echo "    Tools: mvn spotbugs:check, mvn checkstyle:check, mvn dependency-check:check"
  echo ""
fi

# === Python + analysis tools ===
if [ "$INSTALL_PYTHON" = true ]; then
  echo "  ■ Python"
  if command -v python3 >/dev/null 2>&1; then
    echo "    ✓ python3 $(python3 --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
  else
    echo "    Installing Python..."
    if command -v brew >/dev/null 2>&1; then
      brew install python3 2>&1 | tail -1
    elif command -v apt-get >/dev/null 2>&1; then
      sudo apt-get install -y python3 python3-pip 2>&1 | tail -1
    fi
  fi
  # Analysis tools
  for tool in ruff mypy bandit pylint; do
    if ! command -v $tool >/dev/null 2>&1; then
      echo "    Installing $tool..."
      pip3 install --user $tool 2>&1 | tail -1
    else
      echo "    ✓ $tool"
    fi
  done
  echo "    Tools: ruff (linter+formatter), mypy (types), bandit (security), pylint (quality)"
  echo ""
fi

# === Universal tools (already covered elsewhere) ===
echo "  ■ Universal (check with: command -v <tool>)"
for tool in gitleaks semgrep trivy osv-scanner checkov shellcheck shfmt; do
  if command -v $tool >/dev/null 2>&1; then
    echo "    ✓ $tool"
  else
    echo "    · $tool (brew install $tool)"
  fi
done

echo ""
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Ensure ~/.local/bin is in your PATH:"
echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
