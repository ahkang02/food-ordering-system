# OpenTofu Setup Guide

This project uses **OpenTofu** (a Terraform fork) for infrastructure management. OpenTofu is 100% compatible with Terraform configurations.

## Why OpenTofu?

- Open source (Mozilla Public License 2.0)
- Terraform-compatible (uses same configuration files)
- Community-driven
- No license restrictions

## Installation

### macOS

```bash
brew install opentofu/tap/opentofu
```

### Linux

```bash
# Download binary
wget https://github.com/opentofu/opentofu/releases/download/v1.6.2/tofu_1.6.2_linux_amd64.zip
unzip tofu_1.6.2_linux_amd64.zip
sudo mv tofu /usr/local/bin/
```

### Windows

```powershell
# Using Chocolatey
choco install opentofu

# Or download from GitHub releases
```

### Verify Installation

```bash
tofu version
```

Should output:
```
OpenTofu v1.6.2
```

## Usage

OpenTofu uses the same commands as Terraform:

```bash
# Initialize
tofu init

# Plan
tofu plan

# Apply
tofu apply

# Destroy
tofu destroy

# Format
tofu fmt

# Validate
tofu validate
```

## Migration from Terraform

If you're already using Terraform:

1. **No code changes needed** - OpenTofu is 100% compatible
2. **Just replace commands:**
   ```bash
   terraform → tofu
   ```
3. **State files are compatible** - Your existing state will work

## CI/CD Integration

The GitHub Actions workflows use OpenTofu:

```yaml
- name: Setup OpenTofu
  uses: opentofu/setup-opentofu@v1
  with:
    tofu_version: 1.6.2
```

## State Backend

OpenTofu supports the same backends as Terraform:
- S3
- Azure Storage
- GCS
- Local
- etc.

Update `main.tf` backend configuration if needed:

```hcl
backend "s3" {
  bucket = "your-state-bucket"
  key    = "food-ordering/tofu.tfstate"
  region = "us-east-1"
}
```

## Resources

- [OpenTofu Documentation](https://opentofu.org/docs)
- [GitHub Repository](https://github.com/opentofu/opentofu)
- [Migration Guide](https://opentofu.org/docs/intro/v1.6/upgrade-guide)

## Troubleshooting

### Command not found

Make sure OpenTofu is in your PATH:
```bash
which tofu
```

### State file issues

OpenTofu can read Terraform state files directly. No migration needed.

### Provider issues

All Terraform providers work with OpenTofu. No changes needed.

