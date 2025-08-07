# CI/CD Setup Guide

This repository is configured with automated CI/CD that runs tests and deploys to Docker Hub when changes are pushed to the main branch.

## Overview

The CI/CD pipeline performs the following steps:

1. **Security Scanning**: Scans Ruby gems and JavaScript dependencies for vulnerabilities
2. **Linting**: Ensures code follows consistent style guidelines
3. **Testing**: Runs the full test suite including system tests
4. **Deployment** (main branch only): 
   - Automatically bumps the version number
   - Builds and pushes Docker images to Docker Hub
   - Creates a GitHub release with the new version tag

## Required GitHub Secrets

To enable Docker Hub deployment, you need to set up the following secrets in your GitHub repository:

### 1. Docker Hub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions, and add:

- **`DOCKER_HUB_USERNAME`**: Your Docker Hub username
- **`DOCKER_HUB_ACCESS_TOKEN`**: A Docker Hub access token (not your password!)

#### How to create a Docker Hub Access Token:

1. Log in to [Docker Hub](https://hub.docker.com)
2. Go to Account Settings → Security
3. Click "New Access Token"
4. Give it a name (e.g., "GitHub Actions")
5. Select "Read, Write, Delete" permissions
6. Copy the generated token and add it to your GitHub secrets

### 2. GitHub Token (Automatic)

The `GITHUB_TOKEN` is automatically provided by GitHub Actions and doesn't need to be configured.

## How the Pipeline Works

### Version Management

- The version is stored in the `VERSION` file at the root of the repository
- On every successful deployment to main, the patch version is automatically incremented (e.g., `1.0.0` → `1.0.1`)
- The version bump is committed back to the repository with `[skip ci]` to avoid triggering another build

### Docker Images

When tests pass on the main branch, the pipeline builds and pushes three Docker image tags:

1. **`latest`**: Always points to the most recent successful build
2. **`<version>`**: Tagged with the specific version number (e.g., `1.0.1`)
3. **`main-<sha>`**: Tagged with the Git commit SHA for traceability

### Multi-Architecture Support

Images are built for both `linux/amd64` and `linux/arm64` architectures.

## Workflow Triggers

The CI/CD pipeline runs on:

- **Pull Requests**: Runs all tests and checks (but no deployment)
- **Pushes to main**: Runs all tests, and deploys if tests pass

## Manual Version Bumps

If you need to manually bump the version (e.g., for major or minor releases):

1. Edit the `VERSION` file
2. Commit and push to main
3. The pipeline will use your specified version and continue incrementing from there

Example:
```bash
echo "2.0.0" > VERSION
git add VERSION
git commit -m "Bump to version 2.0.0"
git push origin main
```

## Docker Usage

After deployment, you can pull and run the images:

```bash
# Pull the latest version
docker pull <your-dockerhub-username>/family-photo-share:latest

# Pull a specific version
docker pull <your-dockerhub-username>/family-photo-share:1.0.1

# Run the container
docker run -p 80:80 \
  -e RAILS_MASTER_KEY=your_rails_master_key \
  <your-dockerhub-username>/family-photo-share:latest
```

## Troubleshooting

### Pipeline Fails on Version Bump

If the pipeline fails during the version bump step, check:

1. The `VERSION` file exists and contains a valid semantic version (e.g., `1.0.0`)
2. The repository has proper permissions for the GitHub Action to push commits

### Docker Build Fails

Common issues:

1. **Missing secrets**: Ensure `DOCKER_HUB_USERNAME` and `DOCKER_HUB_ACCESS_TOKEN` are set correctly
2. **Invalid Docker Hub credentials**: Verify your access token has the correct permissions
3. **Docker Hub repository doesn't exist**: Create the repository on Docker Hub first, or ensure it matches the username

### Tests Fail

The deployment only triggers if ALL tests pass. Check the test logs in the GitHub Actions tab to identify and fix any failing tests.

## Skipping CI

To skip CI/CD for a commit (e.g., documentation changes), include `[skip ci]` in your commit message:

```bash
git commit -m "Update documentation [skip ci]"
```

## GitHub Releases

Every successful deployment creates a GitHub release with:

- Version tag (e.g., `v1.0.1`)
- Release notes including Docker image information
- Automatic changelog based on commit messages

You can view all releases in the "Releases" section of your GitHub repository.