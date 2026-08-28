#!/usr/bin/env bash
# Setup messy AI-generated project for demo
set -o errexit
set -o nounset
set -o pipefail
alias cpm=./cpm
cd "$(mktemp -d)"
cpm new code-cpp-auth-service >/dev/null
cd code-cpp-auth-service
# Write badly formatted code with a hardcoded secret
cat > src/main.cpp << 'CPP'
#include <iostream>
int main(){auto secret="sk-1234";int a=1;int b=2;int c=3;int d=4;int e=5;int f=6;int g=7;int h=8;int i=9;int j=10;return 0;}
CPP
