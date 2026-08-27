#!/usr/bin/env bash
# TRANS-002: curl insecure
curl -k https://api.example.com/data
curl --insecure https://internal.api/health

# TRANS-003: wget no check
wget --no-check-certificate https://files.example.com/update.tar.gz

# TRANS-007: git ssl no verify
export GIT_SSL_NO_VERIFY=true
