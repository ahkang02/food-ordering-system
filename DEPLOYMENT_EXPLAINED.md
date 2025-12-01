# Deployment Approach Explained

## Previous Approach (Before Artifacts)

### How It Worked

The previous workflow **did NOT use GitHub Actions artifacts**. Instead, it used a **direct build-and-deploy** approach:

```
1. Build code in GitHub Actions runner
2. Create ZIP package in runner
3. Upload ZIP directly to S3
4. EC2 instances download from S3
```

### Step-by-Step Flow

**For .NET:**
```yaml
1. dotnet publish → Creates files in ./publish directory
2. zip -r deployment-package.zip . → Creates ZIP in runner
3. aws s3 cp deployment-package.zip s3://bucket/... → Uploads to S3
4. EC2 downloads from S3 via SSM command
5. EC2 unzips and deploys
```

**For PHP:**
```yaml
1. zip -r php-deployment-package.zip . → Creates ZIP in runner
2. aws s3 cp php-deployment-package.zip s3://bucket/... → Uploads to S3
3. EC2 downloads from S3 via SSM command
4. EC2 unzips and deploys
```

### Why This Works

- ✅ **S3 is the artifact store** - Not GitHub Actions artifacts
- ✅ **Direct deployment** - No intermediate artifact download needed
- ✅ **Versioned in S3** - Each deployment gets a unique S3 key
- ✅ **EC2 can access S3** - Via IAM roles, no GitHub needed

### The Problem

The issue was:
- ❌ **No visibility** - Can't see/download artifacts from GitHub UI
- ❌ **No traceability** - Hard to link GitHub run to S3 file
- ❌ **No reusability** - Can't reuse artifacts in other workflows
- ❌ **No CI artifacts** - Build artifacts weren't saved for inspection

## Current Approach (With Artifacts)

### How It Works Now

We now use a **hybrid approach**:

```
1. Build code in GitHub Actions runner
2. Create ZIP package
3. Upload to GitHub Actions artifacts (for visibility)
4. Upload to S3 (for deployment)
5. EC2 instances download from S3
```

### Benefits

- ✅ **GitHub Artifacts** - Visible in Actions UI, downloadable
- ✅ **S3 Storage** - For actual deployment (EC2 access)
- ✅ **Versioned** - Includes commit SHA in filename
- ✅ **Traceable** - Can link GitHub run to S3 deployment
- ✅ **Reusable** - Artifacts can be downloaded in other workflows

## Most Common Practices

### Practice 1: S3-Only (Simple, Common for AWS)

**When to use:**
- AWS-native deployments
- EC2/ECS/Lambda deployments
- When you don't need GitHub artifact visibility

**Flow:**
```
Build → Package → Upload to S3 → Deploy from S3
```

**Pros:**
- Simple
- Direct
- No artifact storage costs
- EC2 has direct S3 access

**Cons:**
- No GitHub artifact visibility
- Harder to debug
- Can't download from GitHub UI

### Practice 2: GitHub Artifacts + S3 (Hybrid - What We Use Now)

**When to use:**
- Need visibility in GitHub
- Want to reuse artifacts
- Need both GitHub and AWS access

**Flow:**
```
Build → Package → Upload to GitHub Artifacts → Upload to S3 → Deploy from S3
```

**Pros:**
- Best of both worlds
- Visible in GitHub
- Accessible from S3
- Can download for debugging

**Cons:**
- Slightly more complex
- Uses both storage systems

### Practice 3: GitHub Artifacts Only (For Non-AWS)

**When to use:**
- Non-AWS deployments
- When deployment target can access GitHub
- Small deployments

**Flow:**
```
Build → Package → Upload to GitHub Artifacts → Download in deploy job → Deploy
```

**Pros:**
- Simple
- All in GitHub
- Good for small projects

**Cons:**
- EC2 can't easily access GitHub artifacts
- Requires GitHub token
- Not ideal for AWS

### Practice 4: Container Registry (Modern, Best Practice)

**When to use:**
- Containerized applications
- Kubernetes/ECS deployments
- Production environments

**Flow:**
```
Build → Create Docker Image → Push to ECR → Deploy from ECR
```

**Pros:**
- Industry standard
- Versioned images
- Easy rollback
- Works with any orchestrator

**Cons:**
- Requires containerization
- More setup

## Recommended Approach for Your Project

### For AWS EC2 Deployments (Your Case)

**Best Practice: GitHub Artifacts + S3 (Current Approach)**

**Why:**
1. **GitHub Artifacts** provide:
   - Visibility in Actions UI
   - Easy download for debugging
   - Artifact retention for compliance
   - Can be used in other workflows

2. **S3 Storage** provides:
   - Direct EC2 access (via IAM)
   - Long-term storage
   - Versioning
   - Lifecycle policies
   - Cost-effective

**Flow:**
```yaml
Build Job:
  - Build application
  - Create ZIP package
  - Upload to GitHub Artifacts (visibility)
  - Upload to S3 (deployment)

Deploy Job:
  - EC2 downloads from S3 (not GitHub)
  - EC2 deploys application
```

### Why Not GitHub Artifacts Only?

**Problem:** EC2 instances can't easily access GitHub artifacts because:
- Requires GitHub token
- Requires internet access
- More complex authentication
- S3 is native to AWS

**Solution:** Use S3 as the deployment source, GitHub artifacts for visibility.

## Comparison Table

| Approach | Visibility | EC2 Access | Complexity | Cost | Best For |
|----------|-----------|------------|------------|------|----------|
| S3 Only | ❌ | ✅ | Low | Low | Simple AWS |
| GitHub + S3 | ✅ | ✅ | Medium | Medium | **Your case** |
| GitHub Only | ✅ | ❌ | Low | Low | Non-AWS |
| Container Registry | ✅ | ✅ | High | Medium | Production |

## What Changed in Your Workflows

### Before (S3 Only)
```yaml
- Build
- Create ZIP
- Upload to S3
- Deploy from S3
```

### After (GitHub + S3)
```yaml
- Build
- Create ZIP
- Upload to GitHub Artifacts ← NEW
- Upload to S3
- Deploy from S3
```

**Key Point:** Deployment still happens from S3. GitHub artifacts are just for visibility and debugging.

## Summary

**Previous approach:** Direct S3 upload (no GitHub artifacts)
- ✅ Works fine
- ❌ No visibility in GitHub
- ❌ Hard to debug

**Current approach:** GitHub artifacts + S3
- ✅ Visible in GitHub UI
- ✅ Still deploys from S3 (EC2 access)
- ✅ Best practice for AWS + GitHub

**Most common for AWS:** S3-only or GitHub+S3 (what we have now)

**Industry standard:** Container registry (for production, but requires containerization)

For your AWS Learner Lab project, the **current hybrid approach (GitHub + S3)** is the best balance of visibility and functionality.

