# Artifacts Documentation

This document explains how artifacts are generated, stored, and used in the CI/CD pipeline.

## Artifact Generation

### .NET Application

**Build Artifact (CI):**
- Created during CI pipeline
- Name: `dotnet-build-artifact`
- Location: `dotnet-food-ordering/publish/`
- Format: ZIP file
- Retention: 7 days

**Deployment Artifact (Deploy):**
- Created during deployment
- Name: `dotnet-deployment-package`
- Location: Published .NET application
- Format: ZIP file
- Retention: 30 days
- Also uploaded to S3: `s3://bucket/dotnet-deployments/YYYYMMDD-HHMMSS-commit-sha.zip`

### PHP Application

**Build Artifact (CI):**
- Created during CI pipeline
- Name: `php-build-artifact`
- Location: `php-food-ordering/`
- Format: ZIP file
- Retention: 7 days

**Deployment Artifact (Deploy):**
- Created during deployment
- Name: `php-deployment-package`
- Location: PHP application directory
- Format: ZIP file
- Retention: 30 days
- Also uploaded to S3: `s3://bucket/php-deployments/YYYYMMDD-HHMMSS-commit-sha.zip`

## Artifact Storage

### GitHub Actions Artifacts

Artifacts are stored in GitHub Actions and can be:
- Downloaded from the Actions UI
- Used in subsequent workflow steps
- Shared between jobs using `actions/download-artifact`

**View Artifacts:**
1. Go to Actions tab
2. Click on a workflow run
3. Scroll to "Artifacts" section
4. Download the artifact

### S3 Storage

Deployment artifacts are also stored in S3 for:
- Long-term retention
- Direct EC2 access
- Version control (includes commit SHA)

**S3 Structure:**
```
s3://bucket-name/
├── dotnet-deployments/
│   └── YYYYMMDD-HHMMSS-commit-sha.zip
└── php-deployments/
    └── YYYYMMDD-HHMMSS-commit-sha.zip
```

## Artifact Usage

### In Workflows

Artifacts are automatically:
1. **Created** during build/publish steps
2. **Uploaded** to GitHub Actions
3. **Uploaded** to S3 (deployment artifacts only)
4. **Deployed** to EC2 instances via SSM

### Downloading Artifacts

**From GitHub Actions:**
```yaml
- name: Download artifact
  uses: actions/download-artifact@v4
  with:
    name: dotnet-build-artifact
    path: ./downloaded-artifact
```

**From S3:**
```bash
aws s3 cp s3://bucket-name/dotnet-deployments/20241201-120000-abc123.zip ./artifact.zip
```

## Artifact Versioning

Deployment artifacts include:
- **Timestamp**: `YYYYMMDD-HHMMSS`
- **Commit SHA**: First 7 characters of commit hash
- **Format**: `YYYYMMDD-HHMMSS-commit-sha.zip`

Example: `20241201-143022-a1b2c3d.zip`

This ensures:
- Unique versioning per deployment
- Traceability to source code
- Easy rollback identification

## Artifact Contents

### .NET Deployment Package

```
dotnet-deployment-package.zip
├── FoodOrdering.dll
├── FoodOrdering.runtimeconfig.json
├── appsettings.json
├── Pages/
├── wwwroot/
└── ... (all published files)
```

### PHP Deployment Package

```
php-deployment-package.zip
├── api/
│   ├── menu.php
│   ├── orders.php
│   └── db_service.php
├── index.php
├── .htaccess
└── ... (all PHP files)
```

## Best Practices

1. **Always check artifact size** - Large artifacts may cause issues
2. **Use retention policies** - Clean up old artifacts
3. **Version artifacts** - Include commit SHA for traceability
4. **Store in S3** - For long-term retention and EC2 access
5. **Download before use** - In multi-job workflows

## Troubleshooting

### Artifact Not Found

- Check if the artifact was created in a previous step
- Verify the artifact name matches exactly
- Check retention period hasn't expired

### Artifact Too Large

- Review what's included in the package
- Exclude unnecessary files (node_modules, etc.)
- Use `.gitignore` patterns in zip creation

### S3 Upload Failed

- Verify AWS credentials
- Check S3 bucket permissions
- Ensure bucket exists

## Artifact Cleanup

**GitHub Actions:**
- Automatic cleanup based on retention days
- Manual deletion from Actions UI

**S3:**
- Lifecycle policies configured in Terraform
- Automatic deletion after 30 days
- Manual cleanup via AWS Console

