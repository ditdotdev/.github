# Datadatdat - Claude Instructions

## Critical Rules

### NEVER Skip Tests
**Tests must always pass.** Never use `-x test`, `--no-test`, or any mechanism to skip tests when building or committing code. If tests fail:
1. Investigate and fix the root cause
2. Tests exist for a reason - they catch real issues
3. Skipping tests masks problems and degrades code quality
4. All commits must have passing tests before being pushed

## Working Style Preferences

### Investigation & Problem-Solving Approach

**Deep dive before fixing**: Always investigate root causes thoroughly rather than applying quick fixes:
- Understand the full chain of dependencies (e.g., Docker Desktop kernel → build environment → artifacts)
- Examine exact technical details (vermagic strings, symbol versions, directory structures)
- Trace issues through multiple layers (kernel headers → module builds → S3 artifacts → container runtime)

**Validate everything with evidence**: After each fix, provide concrete validation:
- Inspect artifacts directly (tar contents, file sizes, timestamps, directory structures)
- Check actual runtime behavior (Docker logs, module loading, error messages)
- Reference specific workflow runs, commit hashes, and line numbers
- Never claim something works without showing evidence

**Systematic verification across repositories**: When checking multi-repo state, use batch commands:
```bash
# Update all workspace repos to master
for d in */; do cd "$d" && git checkout master && git pull && cd ..; done

# Verify version consistency across Go modules
grep -r "github.com/dolt/remote-sdk-go" */go.mod
```

### Multi-Repository Operations

**Workspace-wide thinking**: Understand that operations often affect 30+ repositories simultaneously:
- "Update all repos" means all workspace folders in `/c/dev`
- Track relationships between repositories (SDK → providers → client → CLI → servers)
- Maintain version alignment across the entire ecosystem

**Structured release process**: Follow multi-phase releases with exact ordering:
1. **Phase 1**: Go SDKs and automated provider PRs
2. **Phase 2**: Kotlin SDKs and providers
3. **Phase 3**: Client libraries
4. **Phase 4**: CLI tools
5. **Phase 5**: Server components
6. **Phase 6**: Remote server with E2E validation

**Preparation before execution**: Before complex operations (releases, major changes):
- Ensure all repos are on master with latest changes pulled
- Clean up documentation (remove obsolete instructions)
- Verify version consistency across dependencies
- Stage everything correctly before proceeding

### Context and Continuity

**Long sessions with continuous flow**: Work sessions may span multiple related tasks:
- Maintain context of what's been completed (e.g., "Java 17 upgrade done, ZFS builder fixed")
- Don't revisit or re-investigate already-solved problems
- Build on previous work in the session (fixes → validation → cleanup → release prep)

**Clean slate for major work**: Before releases or significant changes:
- Workspace in known-good state (all repos on master)
- Documentation hygiene (obsolete commands removed)
- Validation complete (tests passing, artifacts verified)

## Diagnosing CI/CD Build Failures

When investigating GitHub Actions or other CI/CD build failures:

1. **Always replicate locally first** - Don't assume errors are transient network issues based solely on log output
   - Use `gh pr checkout <PR_NUMBER>` to check out the branch locally
   - Run the exact same commands that failed in CI (check the workflow files in `.github/workflows/`)
   - This reveals the true root cause vs. misleading network timeouts or infrastructure issues

2. **Common pitfalls to avoid:**
   - Dismissing errors as "intermittent" without verification
   - Not checking version compatibility (e.g., Gradle 9.x requires Java 17+)
   - Missing API changes between versions (e.g., Gradle's component selection API changed in 9.x)

3. **Investigation workflow:**
   - Use `gh pr view <PR_NUMBER> --json statusCheckRollup` to see failed checks
   - Use `gh run view <RUN_ID> --log-failed` to get failure logs
   - Check out the branch and replicate the exact build command
   - Verify environment requirements (Java version, etc.)
   - Look for API compatibility issues in dependency upgrades

### Example: Gradle Version Upgrades

When Gradle is upgraded (e.g., 8.x → 9.x):
- Check Java version compatibility (Gradle 9+ requires Java 17+)
- Review breaking API changes (component selection, task configuration, etc.)
- Test locally before assuming CI infrastructure issues

## Architecture Overview

Dolt is a proprietary multi-component data versioning platform with ZFS integration and Docker-based containerization. The ecosystem consists of:

- **dolt** (CLI) - Go-based CLI that orchestrates data versioning operations
- **dolt-server** - Core Docker container providing ZFS storage, PostgreSQL, and API services
- **dolt-client-go** - Auto-generated Go client from OpenAPI spec
- **Remote providers** - Dual-language (Go/Kotlin) implementations for S3, SSH, S3Web storage backends
- **SDK libraries** - `remote-sdk-go` and `remote-sdk` for building new remote providers
- **Testing framework** - BATS (Bash Automated Testing System) for cross-platform end-to-end tests

## Critical Development Workflows

### Build Commands
```bash
# CLI builds for all platforms
make release   # Creates cross-platform binaries in release/

# Individual platform builds
make windows   # Creates dolt.exe
make linux-amd64
make darwin-arm64

# Local development build
make build     # Creates build/dolt
```

### Testing Infrastructure
```bash
# Full end-to-end test suite (requires AWS/SSH setup)
make e2e

# Individual test categories
make test-getting-started
make test-s3-workflow      # Requires AWS credentials
make test-ssh-workflow     # Requires SSH key setup
```

**Critical Test Recovery**: After failed `make e2e` runs, always reset before retrying:
```bash
./dolt.exe uninstall -f   # Cleans up corrupted test state
make e2e                   # Safe to retry after uninstall
```

### Windows/WSL2 ZFS Requirements
**Critical**: Before any testing on Windows/WSL2, run:
```powershell
cd cleanslate
.\setup-zfs-pools.ps1 -Clean -VerifyDocker
```
This creates required ZFS pools that Dolt containers depend on.

## Provider Architecture Pattern

Remote providers follow a dual-implementation pattern:
- **Go version** (`*-remote-go`) - Plugin-based using HashiCorp go-plugin
- **Kotlin version** (`*-remote`) - Gradle-based JVM implementations

Both implement the `remote-sdk` interface for push/pull operations to external storage.

## Key Conventions

### Project Structure
- Each component has identical files: `CODEOWNERS`, `DEVELOPING.md`, `LICENSE`
- Go projects use `go.mod` with version `go 1.25.1`
- Kotlin projects use `build.gradle.kts` with dependency update plugins
- All repos follow semantic versioning with `v0.x.x` tags

### Docker Integration
- Main container: `dolt/dolt:latest` (server + ZFS + PostgreSQL)
- ZFS builder: `dolt/zfs-builder:latest` (for kernel module compilation)
- SSH test: `dolt/ssh-test-server:latest` (testing only)
- Use `--registry` flag to override Docker Hub registry

#### Container Orchestration Details
The `dolt-server` container runs multiple services:
- **ZFS utilities** - Direct filesystem integration for data versioning
- **PostgreSQL database** - Metadata storage for commits, repositories, and remote configurations
- **docker-volume-proxy** - Bridges Docker volumes to ZFS datasets
- **Dolt API server** - REST endpoints consumed by CLI and client libraries

**Volume Management**: Dolt creates ZFS datasets that appear as Docker volumes. The volume proxy component requires `socat` package (included in Dockerfile) to handle volume driver communication between Docker daemon and ZFS subsystem.

**Pool Requirements**:
- `dolt-docker` pool - Required for container volume operations
- `dolt` pool - Optional but recommended for CLI operations

### Testing Framework (BATS)
Tests use BATS (Bash Automated Testing System) for cross-platform compatibility:
```bash
# Run individual test suites
bats tests/endtoend/infrastructure/install.bats
bats tests/endtoend/getting-started/getting-started.bats

# Run via Makefile targets
make test-install
make test-getting-started
```

### Go Module Dependencies
Main CLI imports remote providers directly:
```go
github.com/dolt/s3-remote-go v0.2.3
github.com/dolt/ssh-remote-go v0.2.2
github.com/dolt/dolt-client-go v0.1.3
```

### Version Management
- CLI version defined in `internal/app/Version.go`
- Client libraries auto-generated from server OpenAPI spec
- Remote providers maintain independent semantic versions
- All repositories use automated GitHub Actions for releases
- Docker images published to `dolt/*` namespace on Docker Hub

## Clean Slate Testing

For complete environment reset and verification:
```powershell
cd cleanslate
.\clean-slate-automation.ps1 -Verbose
```

This handles Docker cleanup, ZFS pool recreation, and complete Dolt reinstallation. Essential for troubleshooting integration issues.

## Demo Infrastructure

The dolt-demos repository contains sample datasets for testing and examples:

### S3 Demo Bucket
- **Production bucket:** `demo-dolt`
- **Web endpoint:** `s3web://demo-dolt.s3-website-us-west-2.amazonaws.com`
- **Available demos:** postgres, dynamodb hello-world examples
- **Scripts:** `build.sh` → `publish.sh` → `destroy.sh` workflow

### Demo Script Patterns
```bash
# PostgreSQL demo (uses postgres:latest with trust auth)
d3 run -n hello-world-postgres -e POSTGRES_HOST_AUTH_METHOD=trust postgres:latest

# DynamoDB demo (uses port 8001 to avoid conflicts)
d3 run -n hello-world-dynamodb -P dolt/dynamodb-local:latest -- -p 8001:8000
```

## Workspace Management

The Dolt ecosystem is organized as a VS Code multi-root workspace. To get the complete list of repositories:

```bash
# From any repository directory in /c/dev
cat ../dolt.code-workspace
```

This workspace file contains all component repositories and is the authoritative source for determining which repositories are part of the Dolt ecosystem.

## File Locations for Common Tasks

- **Adding CLI commands**: `internal/app/commands/`
- **Provider interface**: `internal/app/providers/Provider.go`
- **Main entry point**: `cmd/dolt/dolt.go`
- **Cross-platform builds**: `Makefile` release targets
- **End-to-end tests**: `tests/endtoend/` with BATS test files
- **Docker configuration**: `Dockerfile` (includes ZFS utilities + socat)
- **Release process**: `RELEASE.md` in main dolt repository
- **Workspace configuration**: `dolt.code-workspace` in `/c/dev` directory

## GitHub Issue Management

When creating GitHub issues with `gh issue create`:
- **Do NOT use labels** - The `--label` flag should never be used
- Use clear titles and detailed markdown bodies
- Link related issues/PRs in the body text when relevant

## Git and GitHub Workflow Patterns

### Standard PR Workflow
1. Create feature/fix branch with descriptive name (e.g., `update/dependencies-1.3.0`, `fix/validateParameters-null-safety`)
2. Make changes and commit with clear, contextual messages
3. Push branch and create PR
4. After merge: `git checkout master && git pull`
5. For versioned releases: Delete and reapply tags at new master tip for consistency

### Tag Management After Merges
```bash
git tag -d 1.3.0           # Delete local tag
git push origin :refs/tags/1.3.0   # Delete remote tag
git tag 1.3.0              # Create new tag at current master
git push origin 1.3.0      # Push new tag
```

### Branch Operations
- Use descriptive branch names that indicate purpose
- Prefer systematic batch updates for similar changes across repos
- Verify changes after merging (check CI status, pull master, verify versions)

### Issue Creation for Deferred Work
- Create issues for non-critical improvements that shouldn't block current work
- Include: problem description, why it matters, proposed solution, scope, and priority
- Example: Configuration improvements, technical debt, future optimizations

## Communication and Evidence Standards

### Providing Evidence for Claims
When making factual claims about code, configurations, or system state:
- **Cite specific locations**: Include file paths, line numbers, function names
- **Link to sources**: Provide GitHub permalinks, PR numbers, commit hashes
- **Show grep/search results**: Display actual output from searches when claiming something exists/doesn't exist
- **Reference tool outputs**: Include relevant terminal output, CI logs, test results
- **Never speculate and claim as fact**: Do not say "This is a known issue" or "This is documented behavior" without citing the actual source

**Examples:**
- ❌ "The workflow uses authentication"
- ✅ "The workflow uses authentication (see line 42 in `.github/workflows/pull-request.yml`)"
- ❌ "All dependencies are at v1.3.0"
- ✅ "All dependencies are at v1.3.0 (verified via grep: 23 Kotlin deps + 15 Go deps = 38 total)"
- ❌ "This is a known issue - containers sometimes can't resolve each other's DNS names"
- ✅ "The auth-server logs show DNS lookup failing for 'postgres' with error: dial tcp: lookup postgres on 172.26.0.2:53: no such host"

### Presentation Preferences
- Use tables for comparing data across multiple items/repos
- Provide systematic verification when checking multiple repositories
- Use emoji indicators sparingly but effectively (✅ ❌ 🔄 ⚠️)

## Technical Implementation Patterns

### Pattern Consistency
When implementing fixes or features:
- Look for existing patterns in other repos before creating new approaches
- Match authentication/configuration patterns across similar components
- Example: GO_MODULES_TOKEN with x-access-token prefix (not bare token)

### Version Alignment
- Maintain consistent versions across entire ecosystem
- Update dependencies in batches by type (Kotlin/Maven, then Go modules)
- Verify alignment after updates with grep searches across workspace

### Workspace-Aware Operations
- Use the multi-root workspace definition as the authoritative repo list
- Don't search outside `/c/dev` workspace boundaries
- Loop over known repos rather than broad filesystem searches

## Development Environment Setup

1. **Prerequisites**: Go 1.25.1+, Docker Desktop, Make, BATS (npm install -g bats)
2. **Windows only**: Run ZFS pool setup script first
3. **AWS testing**: Configure `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`
4. **SSH testing**: Generate SSH keypair using provided scripts
5. **Clean builds**: Use `make clean` before major changes to clear all caches
