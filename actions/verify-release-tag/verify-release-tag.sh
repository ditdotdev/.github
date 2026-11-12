#!/usr/bin/env bash
# Copyright Dit 2026
# SPDX-License-Identifier: BUSL-1.1
#
# Fails unless the workflow run was started by a release tag: a tag named
# X.Y.Z (or vX.Y.Z when TAG_PREFIX=v) on a commit that is already on the
# default branch.
#
# Release workflows publish whatever tag starts them, and a published version
# cannot be withdrawn from Maven Central, the Go module proxy or Docker Hub.
# This check stops a mistyped tag, or a tag on a branch commit, before the
# build. It guards against mistakes only: who may create tags is enforced by
# the organization tag ruleset, not here.
#
# Run it from a checkout of the tagged commit. Inputs (environment):
#   GITHUB_REF      the ref that started the run (set by GitHub Actions)
#   GITHUB_SHA      the commit that ref points at (set by GitHub Actions)
#   TAG_PREFIX      "" (default) for X.Y.Z tags, "v" for vX.Y.Z tags
#   DEFAULT_BRANCH  branch releases are cut from (default: master)

set -euo pipefail

ref="${GITHUB_REF:-}"
prefix="${TAG_PREFIX:-}"
branch="${DEFAULT_BRANCH:-master}"

fail() {
    echo "::error::$*"
    exit 1
}

case "$prefix" in
    "" | v) ;;
    *) fail "TAG_PREFIX must be empty or \"v\", got \"$prefix\"" ;;
esac

case "$ref" in
    refs/tags/*) ;;
    *) fail "\"$ref\" is not a tag; releases start from a tag" ;;
esac
tag="${ref#refs/tags/}"

if [[ ! "$tag" =~ ^${prefix}[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    fail "tag \"$tag\" is not a release version (expected ${prefix}X.Y.Z)"
fi

# actions/checkout leaves a shallow, single-commit clone by default, so fetch
# the default branch with full history before asking about ancestry.
fetch_args=(--quiet --no-tags)
if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
    fetch_args+=(--unshallow)
fi
if ! git fetch "${fetch_args[@]}" origin "+refs/heads/$branch:refs/remotes/origin/$branch"; then
    fail "could not fetch $branch from origin to check tag \"$tag\""
fi

if ! git merge-base --is-ancestor "${GITHUB_SHA}^{commit}" "refs/remotes/origin/$branch"; then
    fail "tag \"$tag\" points at ${GITHUB_SHA}, which is not on $branch; merge first, then tag $branch"
fi

echo "Release tag $tag is a version tag on $branch."
