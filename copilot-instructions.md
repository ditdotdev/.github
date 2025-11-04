# Datadatdat Data Management Platform - AI Agent Instructions

## Architecture Overview

Datadatdat is a proprietary multi-component data versioning platform with ZFS integration and Docker-based containerization. The ecosystem consists of:

- **datadatdat** (CLI) - Go-based CLI that orchestrates data versioning operations
- **datadatdat-server** - Core Docker container providing ZFS storage, PostgreSQL, and API services  
- **datadatdat-client-go** - Auto-generated Go client from OpenAPI spec
- **Remote providers** - Dual-language (Go/Kotlin) implementations for S3, SSH, S3Web storage backends
- **SDK libraries** - `remote-sdk-go` and `remote-sdk` for building new remote providers
- **Testing framework** - BATS (Bash Automated Testing System) for cross-platform end-to-end tests

## Critical Development Workflows

### Build Commands
```bash
# CLI builds for all platforms
make release   # Creates cross-platform binaries in release/

# Individual platform builds
make windows   # Creates datadatdat.exe  
make linux-amd64
make darwin-arm64

# Local development build
make build     # Creates build/datadatdat
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
./datadatdat.exe uninstall -f   # Cleans up corrupted test state
make e2e                   # Safe to retry after uninstall
```

### Windows/WSL2 ZFS Requirements
**Critical**: Before any testing on Windows/WSL2, run:
```powershell
cd cleanslate
.\setup-zfs-pools.ps1 -Clean -VerifyDocker
```
This creates required ZFS pools that Datadatdat containers depend on.

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
- Main container: `datadatdat/datadatdat:latest` (server + ZFS + PostgreSQL)
- ZFS builder: `datadatdat/zfs-builder:latest` (for kernel module compilation)
- SSH test: `datadatdat/ssh-test-server:latest` (testing only)
- Use `--registry` flag to override Docker Hub registry

#### Container Orchestration Details
The `datadatdat-server` container runs multiple services:
- **ZFS utilities** - Direct filesystem integration for data versioning
- **PostgreSQL database** - Metadata storage for commits, repositories, and remote configurations
- **docker-volume-proxy** - Bridges Docker volumes to ZFS datasets
- **Datadatdat API server** - REST endpoints consumed by CLI and client libraries

**Volume Management**: Datadatdat creates ZFS datasets that appear as Docker volumes. The volume proxy component requires `socat` package (included in Dockerfile) to handle volume driver communication between Docker daemon and ZFS subsystem.

**Pool Requirements**: 
- `datadatdat-docker` pool - Required for container volume operations
- `datadatdat` pool - Optional but recommended for CLI operations

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
github.com/datadatdat/s3-remote-go v0.2.3
github.com/datadatdat/ssh-remote-go v0.2.2
github.com/datadatdat/datadatdat-client-go v0.1.3
```

### Version Management
- CLI version defined in `internal/app/Version.go`
- Client libraries auto-generated from server OpenAPI spec
- Remote providers maintain independent semantic versions
- All repositories use automated GitHub Actions for releases
- Docker images published to `datadatdat/*` namespace on Docker Hub

## Clean Slate Testing

For complete environment reset and verification:
```powershell
cd cleanslate
.\clean-slate-automation.ps1 -Verbose
```

This handles Docker cleanup, ZFS pool recreation, and complete Datadatdat reinstallation. Essential for troubleshooting integration issues.

## Demo Infrastructure

The datadatdat-demos repository contains sample datasets for testing and examples:

### S3 Demo Bucket
- **Production bucket:** `demo-datadatdat`
- **Web endpoint:** `s3web://demo-datadatdat.s3-website-us-west-2.amazonaws.com`
- **Available demos:** postgres, dynamodb hello-world examples
- **Scripts:** `build.sh` → `publish.sh` → `destroy.sh` workflow

### Demo Script Patterns
```bash
# PostgreSQL demo (uses postgres:latest with trust auth)
d3 run -n hello-world-postgres -e POSTGRES_HOST_AUTH_METHOD=trust postgres:latest

# DynamoDB demo (uses port 8001 to avoid conflicts)
d3 run -n hello-world-dynamodb -P datadatdat/dynamodb-local:latest -- -p 8001:8000
```

## Workspace Management

The Datadatdat ecosystem is organized as a VS Code multi-root workspace. To get the complete list of repositories:

```bash
# From any repository directory in /c/dev
cat ../datadatdat.code-workspace
```

This workspace file contains all component repositories and is the authoritative source for determining which repositories are part of the Datadatdat ecosystem.

## File Locations for Common Tasks

- **Adding CLI commands**: `internal/app/commands/`
- **Provider interface**: `internal/app/providers/Provider.go`
- **Main entry point**: `cmd/datadatdat/datadatdat.go`
- **Cross-platform builds**: `Makefile` release targets
- **End-to-end tests**: `tests/endtoend/` with BATS test files
- **Docker configuration**: `Dockerfile` (includes ZFS utilities + socat)
- **Release process**: `RELEASE.md` in main datadatdat repository
- **Workspace configuration**: `datadatdat.code-workspace` in `/c/dev` directory

## Development Environment Setup

1. **Prerequisites**: Go 1.25.1+, Docker Desktop, Make, BATS (npm install -g bats)
2. **Windows only**: Run ZFS pool setup script first
3. **AWS testing**: Configure `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`
4. **SSH testing**: Generate SSH keypair using provided scripts
5. **Clean builds**: Use `make clean` before major changes to clear all caches