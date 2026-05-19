#!/usr/bin/env bash
# local.sh — Local-only provider (no remote sync).
# @see ADR-129
# Use this when you don't want to connect to any external service.

issue_provider_available() { return 1; }
issue_provider_name() { echo "local"; }
issue_sync_push_one() { :; }
issue_sync_pull() { :; }
