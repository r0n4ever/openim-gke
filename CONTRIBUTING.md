# Contributing to OpenIM on GKE

Thank you for your interest in contributing to this project! This document provides guidelines for contributing improvements, bug fixes, and new features.

## 🎯 Project Goals

This project aims to provide:
1. **One-click deployment** of OpenIM on GKE
2. **Production-ready** configuration with best practices
3. **High-performance alternatives** to standard components
4. **Clear documentation** for operations and troubleshooting
5. **Easy customization** for different environments

## 🤝 How to Contribute

### Reporting Issues

When reporting an issue, please include:

- **Clear description** of the problem
- **Steps to reproduce** the issue
- **Expected behavior** vs actual behavior
- **Environment details**:
  - GKE cluster version
  - Component versions (Redpanda, Dragonfly, SeaweedFS, OpenIM)
  - Node machine types and count
  - Region/zone
- **Relevant logs** or error messages
- **Configuration files** (sanitized, no secrets)

### Suggesting Enhancements

We welcome suggestions for:
- Performance improvements
- New component alternatives
- Better configurations
- Documentation improvements
- Automation enhancements

Please open an issue with:
- **Use case** description
- **Proposed solution**
- **Benefits** and potential drawbacks
- **Implementation notes** (if applicable)

## 📝 Development Guidelines

### Directory Structure

When adding new components or features, follow the existing structure:

```
├── tofu/                    # Infrastructure code
├── helm/                    # Helm configurations (numbered by installation order)
│   ├── XX-component/       # Component directory
│   │   ├── README.md       # Component-specific documentation
│   │   ├── values.yaml     # Helm values
│   │   └── templates/      # Custom chart templates (if needed)
├── envs/                   # Environment configurations
└── docs/                   # Additional documentation (if needed)
```

### Naming Conventions

- **Directories**: Use lowercase with hyphens (e.g., `30-dragonfly`)
- **Files**: Use lowercase with hyphens or underscores
- **Helm releases**: Use component name (e.g., `redpanda`, `dragonfly`)
- **Namespaces**: Use component name (e.g., `redpanda`, `dragonfly`, `openim`)
- **Services**: Follow Kubernetes conventions (lowercase, hyphens)

### Code Standards

#### Terraform/OpenTofu

- Use consistent indentation (2 spaces)
- Add comments for complex logic
- Use variables for all configurable values
- Follow Terraform best practices:
  - Use resource dependencies explicitly
  - Avoid hard-coded values
  - Use data sources when appropriate

```hcl
# Good
resource "google_container_cluster" "openim_cluster" {
  name     = var.cluster_name
  location = var.region
  
  # Comment explaining why this is needed
  remove_default_node_pool = true
  initial_node_count       = 1
}

# Bad
resource "google_container_cluster" "cluster" {
  name     = "my-cluster"  # Hard-coded
  location = "us-central1"  # Hard-coded
}
```

#### Helm Values

- Use YAML best practices
- Add comments explaining each section
- Group related settings
- Provide default values that work
- Mark required changes with TODO

```yaml
# Good
# Redpanda broker configuration
broker:
  # Number of replicas for high availability
  replicas: 3  # Recommended minimum for production
  
  # Resource limits
  resources:
    limits:
      cpu: 1000m
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 1Gi

# Bad
broker:
  replicas: 3
  resources:
    limits:
      cpu: 1000m
      memory: 2Gi
```

### Documentation Standards

Every component must have:

1. **README.md** with:
   - Purpose and overview
   - Why this component/alternative
   - Installation instructions
   - Verification steps
   - Configuration notes
   - Troubleshooting tips
   - Production considerations

2. **Inline comments** in configuration files

3. **TODO markers** for:
   - Required changes before production
   - Known limitations
   - Future improvements

#### Documentation Template

```markdown
# Component Name - Brief Description

Overview paragraph explaining what this component does and why it's used.

## Why Component X?

**Advantages:**
- Benefit 1
- Benefit 2

**Trade-offs:**
- Limitation 1
- Limitation 2

## Installation

\`\`\`bash
# Step-by-step commands
\`\`\`

## Verification

\`\`\`bash
# How to verify it's working
\`\`\`

## Configuration Notes

Key configuration points...

## Troubleshooting

Common issues and solutions...

## Production Considerations

What to change for production...
```

## 🔄 Contribution Workflow

### 1. Fork and Clone

```bash
# Fork the repository on GitHub, then:
git clone https://github.com/YOUR_USERNAME/openim-gke.git
cd openim-gke

# Add upstream remote
git remote add upstream https://github.com/r0n4ever/openim-gke.git
```

### 2. Create a Branch

```bash
# Create a feature branch
git checkout -b feature/your-feature-name

# Or a bugfix branch
git checkout -b fix/issue-description
```

### 3. Make Changes

- Follow the guidelines above
- Test your changes thoroughly
- Update documentation
- Add comments where needed

### 4. Test Your Changes

Before submitting:

- [ ] **Syntax check** all YAML and Terraform files
  ```bash
  # Terraform
  cd tofu/
  tofu fmt -check
  tofu validate
  
  # Helm
  helm lint helm/XX-component/
  ```

- [ ] **Test deployment** if possible
  ```bash
  # In a test GKE cluster
  ./deploy.sh
  ```

- [ ] **Verify documentation** is clear and accurate
- [ ] **Check for secrets** or sensitive information
- [ ] **Test rollback** procedures if applicable

### 5. Commit Changes

Use clear, descriptive commit messages:

```bash
# Good commit messages
git commit -m "Add PostgreSQL as alternative database option"
git commit -m "Fix Redpanda connection timeout issue #123"
git commit -m "Update SeaweedFS to version 3.50"
git commit -m "Improve OpenIM scaling configuration"

# Bad commit messages
git commit -m "Update files"
git commit -m "Fix bug"
git commit -m "Changes"
```

### 6. Push and Create PR

```bash
# Push to your fork
git push origin feature/your-feature-name

# Create Pull Request on GitHub
```

## 📋 Pull Request Guidelines

Your PR should:

1. **Have a clear title** describing the change
2. **Reference issues** it addresses (if any)
3. **Include description** with:
   - What changed
   - Why it changed
   - How to test
   - Any breaking changes
4. **Update documentation** if behavior changes
5. **Pass all checks** (if CI/CD is set up)

### PR Template

```markdown
## Description
Brief description of changes

## Motivation
Why is this change needed?

## Changes Made
- Change 1
- Change 2

## Testing
How to test these changes

## Breaking Changes
Any breaking changes? How to migrate?

## Checklist
- [ ] Code follows project guidelines
- [ ] Documentation updated
- [ ] Tested in GKE environment
- [ ] No secrets committed
- [ ] README updated if needed
```

## 🎨 Component Contribution Guidelines

### Adding a New Component

When adding a new Helm component:

1. **Choose appropriate number** in sequence (e.g., `50-new-component`)
2. **Create directory structure**:
   ```
   helm/50-new-component/
   ├── README.md
   ├── values.yaml
   └── templates/  (if custom chart)
   ```

3. **Document thoroughly**:
   - Why this component?
   - How it integrates with OpenIM
   - Configuration options
   - Troubleshooting tips

4. **Update main README.md**:
   - Add to directory structure
   - Add to installation steps
   - Add to validation checklist
   - Update quick reference if needed

5. **Update deploy.sh** to include installation

### Replacing a Component

When proposing a component replacement:

1. **Justify the replacement**:
   - Performance benefits
   - Cost savings
   - Operational simplicity
   - API compatibility

2. **Document migration**:
   - Migration steps
   - Data migration (if any)
   - Rollback procedures

3. **Maintain compatibility**:
   - No OpenIM code changes required
   - Standard API compatibility
   - Clear configuration mapping

### Adding Environment Support

When adding support for new environments (prod, staging):

1. **Create new tfvars file**: `envs/prod.tfvars`
2. **Document differences** from dev environment
3. **Update README** with environment-specific notes
4. **Consider security** implications

## 🧪 Testing Guidelines

### Local Testing

Before submitting PR:

```bash
# 1. Validate Terraform
cd tofu/
tofu init
tofu validate
tofu fmt -check

# 2. Lint Helm charts
helm lint helm/*/

# 3. Check for syntax errors
yamllint helm/*/values.yaml

# 4. Test in GKE (if possible)
# Deploy to test cluster
# Run verification checklist
# Test upgrade procedures
# Test rollback
```

### Integration Testing

If you have access to GKE:

1. **Deploy from scratch**
2. **Run all verification steps**
3. **Test component interactions**
4. **Test failure scenarios**
5. **Verify monitoring/logging**
6. **Document any issues**

## 📚 Documentation Contributions

Documentation improvements are always welcome!

Areas that need documentation:
- Performance tuning guides
- Cost optimization tips
- Multi-region deployment
- Advanced troubleshooting
- Migration guides
- Use case examples

### Documentation Style

- **Clear and concise**
- **Step-by-step instructions**
- **Include examples**
- **Use code blocks** for commands
- **Add screenshots** where helpful (for UI)
- **Keep updated** with component versions

## 🐛 Bug Fixes

When fixing bugs:

1. **Reference the issue** number
2. **Explain root cause** in PR description
3. **Describe the fix**
4. **Add prevention measures** (e.g., validation, tests)
5. **Update documentation** if bug revealed gap

## 🚀 Performance Improvements

When proposing performance improvements:

1. **Provide benchmarks**:
   - Before metrics
   - After metrics
   - Test methodology

2. **Document trade-offs**:
   - Resource usage changes
   - Complexity changes
   - Cost implications

3. **Update recommendations** in documentation

## 🔒 Security Considerations

When contributing security-related changes:

- **Never commit secrets** or credentials
- **Use Kubernetes secrets** for sensitive data
- **Document security implications**
- **Follow principle of least privilege**
- **Enable security features** by default
- **Document security configuration**

## 🎓 Learning Resources

To contribute effectively, familiarize yourself with:

- **Kubernetes**: https://kubernetes.io/docs/home/
- **Helm**: https://helm.sh/docs/
- **Terraform/OpenTofu**: https://opentofu.org/docs/
- **GKE**: https://cloud.google.com/kubernetes-engine/docs
- **OpenIM**: https://github.com/openimsdk/open-im-server

## 💬 Communication

- **GitHub Issues**: For bugs, features, questions
- **Pull Requests**: For code contributions
- **Discussions**: For general discussions (if enabled)

## 📄 License

By contributing, you agree that your contributions will be licensed under the same license as this project.

## 🙏 Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes
- Git commit history

## ❓ Questions?

If you have questions about contributing:

1. Check existing documentation
2. Search existing issues
3. Open a new issue with your question
4. Tag it as "question"

---

Thank you for contributing to OpenIM on GKE! 🎉

Your contributions help make this project better for everyone.
