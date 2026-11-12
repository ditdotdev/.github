#!/usr/bin/env bats
# Copyright Dit 2026
# SPDX-License-Identifier: BUSL-1.1
#
# Tests for verify-release-tag.sh, the check that runs first in every release
# workflow. A release must come from a version tag (X.Y.Z, or vX.Y.Z where the
# repo uses a "v" prefix) on a commit that is already on the default branch.
#
# Each test builds a throwaway "origin" repository and a clone of it checked
# out at the tag, the way actions/checkout leaves a runner, so no network is
# needed.

setup() {
    SCRIPT="$BATS_TEST_DIRNAME/../verify-release-tag.sh"
    ORIGIN="$(native_path "$BATS_TEST_TMPDIR")/origin"
    WORK="$(native_path "$BATS_TEST_TMPDIR")/work"
    # A file:// URL, not a bare path, so that --depth is honored.
    ORIGIN_URL="file://$ORIGIN"
    export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
    export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null

    git init -q -b master "$ORIGIN"
    commit_on_origin "first"
    commit_on_origin "second"
    commit_on_origin "third"
}

# Git for Windows resolves /tmp differently from the MSYS shell that runs
# bats, so hand git a native path there. Elsewhere this is a no-op.
native_path() {
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -m "$1"
    else
        echo "$1"
    fi
}

commit_on_origin() {
    echo "$1" >> "$ORIGIN/file.txt"
    git -C "$ORIGIN" add file.txt
    git -C "$ORIGIN" commit -q -m "$1"
}

# checkout_tag TAG [clone args...]: clone origin at TAG into $WORK and export
# the variables a tag-triggered workflow run would see.
checkout_tag() {
    local tag="$1"
    shift
    git clone -q "$@" --branch "$tag" "$ORIGIN_URL" "$WORK" 2>/dev/null
    export GITHUB_REF="refs/tags/$tag"
    GITHUB_SHA="$(git -C "$WORK" rev-parse HEAD)"
    export GITHUB_SHA
    cd "$WORK"
}

@test "accepts X.Y.Z on the tip of master" {
    git -C "$ORIGIN" tag 1.10.5
    checkout_tag 1.10.5
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1.10.5"* ]]
}

@test "accepts X.Y.Z on an earlier master commit" {
    git -C "$ORIGIN" tag 1.10.5 HEAD~1
    checkout_tag 1.10.5
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "accepts a tag on master from a shallow checkout" {
    git -C "$ORIGIN" tag 1.10.5 HEAD~1
    checkout_tag 1.10.5 --depth 1
    [ "$(git rev-parse --is-shallow-repository)" = "true" ]
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "accepts an annotated tag on master" {
    git -C "$ORIGIN" tag -a 1.10.5 -m "release"
    checkout_tag 1.10.5
    run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "accepts vX.Y.Z when the prefix is v" {
    git -C "$ORIGIN" tag v1.10.5
    checkout_tag v1.10.5
    TAG_PREFIX=v run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "rejects a tag named test" {
    git -C "$ORIGIN" tag test
    checkout_tag test
    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not a release version"* ]]
}

@test "rejects vX.Y.Z when no prefix is expected" {
    git -C "$ORIGIN" tag v1.10.5
    checkout_tag v1.10.5
    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not a release version"* ]]
}

@test "rejects X.Y.Z when the prefix is v" {
    git -C "$ORIGIN" tag 1.10.5
    checkout_tag 1.10.5
    TAG_PREFIX=v run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not a release version"* ]]
}

@test "rejects incomplete and decorated versions" {
    for tag in 1.10 1.10.5.1 1.10.5-rc1 1.10.x 01.10.5a; do
        export GITHUB_REF="refs/tags/$tag" GITHUB_SHA=unused
        run bash "$SCRIPT"
        [ "$status" -ne 0 ]
        [[ "$output" == *"not a release version"* ]]
    done
}

@test "rejects a ref that is not a tag" {
    export GITHUB_REF="refs/heads/1.10.5" GITHUB_SHA=unused
    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not a tag"* ]]
}

@test "rejects a version tag on a commit that is not on master" {
    git -C "$ORIGIN" checkout -q -b side
    commit_on_origin "side work"
    git -C "$ORIGIN" tag 1.10.5
    git -C "$ORIGIN" checkout -q master
    checkout_tag 1.10.5
    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not on master"* ]]
}

@test "rejects an off-master tag from a shallow checkout" {
    git -C "$ORIGIN" checkout -q -b side
    commit_on_origin "side work"
    git -C "$ORIGIN" tag 1.10.5
    git -C "$ORIGIN" checkout -q master
    checkout_tag 1.10.5 --depth 1
    run bash "$SCRIPT"
    [ "$status" -ne 0 ]
    [[ "$output" == *"not on master"* ]]
}

@test "checks against the branch named in DEFAULT_BRANCH" {
    git -C "$ORIGIN" checkout -q -b main
    commit_on_origin "main work"
    git -C "$ORIGIN" tag 1.10.5
    git -C "$ORIGIN" checkout -q master
    checkout_tag 1.10.5
    DEFAULT_BRANCH=main run bash "$SCRIPT"
    [ "$status" -eq 0 ]
}

@test "fails when the default branch cannot be fetched" {
    git -C "$ORIGIN" tag 1.10.5
    checkout_tag 1.10.5
    DEFAULT_BRANCH=no-such-branch run bash "$SCRIPT"
    [ "$status" -ne 0 ]
}
