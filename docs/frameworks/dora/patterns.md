# DORA Metrics Patterns

This document describes the four DORA (DevOps Research and Assessment) metrics from the Accelerate book, with thresholds and checkable patterns for cpm.

## Overview

DORA metrics measure software delivery performance and operational efficiency. They correlate with organizational performance and are used to identify elite performers.

| Metric | What it measures |
|--------|------------------|
| **Deployment Frequency** | How often you deploy to production |
| **Lead Time for Changes** | Time from commit to production |
| **Change Failure Rate** | Percentage of deployments causing failures |
| **Mean Time to Recovery (MTTR)** | How quickly you recover from failures |

---

## Metric Thresholds

### Deployment Frequency

| Level | Frequency | Description |
|-------|-----------|-------------|
| Elite | On demand | Multiple deploys per day |
| High | Daily to weekly | At least once per day |
| Medium | Weekly to monthly | At least once per week |
| Low | Monthly to yearly | Less than once per month |

### Lead Time for Changes

| Level | Lead Time | Description |
|-------|-----------|-------------|
| Elite | < 1 hour | From commit to production |
| High | 1 day to 1 week | |
| Medium | 1 week to 1 month | |
| Low | 1 month to 6 months | |

### Change Failure Rate

| Level | Failure Rate | Description |
|-------|--------------|-------------|
| Elite | 0-15% | Percentage of deployments causing failures |
| High | 16-30% | |
| Medium | 16-30% | |
| Low | 46-60% | |

### Mean Time to Recovery

| Level | MTTR | Description |
|-------|------|-------------|
| Elite | < 1 hour | Time to restore service after failure |
| High | < 1 day | |
| Medium | 1 day to 1 week | |
| Low | 1 week to 1 month | |

---

## Checkable Patterns from Git Log

### Deployment Frequency (Proxy)

**What to check**: Commit frequency in the last 4 weeks.

```bash
# Commits in last 4 weeks
git log --since="4 weeks ago" --oneline | wc -l

# Weekly breakdown
git log --since="1 week ago" --oneline | wc -l
git log --since="2 weeks ago" --until="1 week ago" --oneline | wc -l
```

**Classification**:

- Elite: > 20 commits/week
- High: 7-20 commits/week
- Medium: 1-7 commits/week
- Low: < 1 commit/week

### Lead Time for Changes (Proxy)

**What to check**: Average time between commits.

```bash
# Time between consecutive commits (in hours)
git log --format="%H %ai" --since="4 weeks ago" | \
  awk 'NR>1 {diff = mktime($2) - mktime(prev); sum += diff; count++} {prev = $2} END {print sum/count/3600}'
```

**Classification**:

- Elite: < 1 hour between commits
- High: 1-24 hours
- Medium: 1-7 days
- Low: > 7 days

### Change Failure Rate (Proxy)

**What to check**: Ratio of revert/fix commits to total.

```bash
# Revert commits
git log --grep="revert" --since="4 weeks ago" --oneline | wc -l

# Fix commits (fix, hotfix, patch)
git log --grep="^fix" --since="4 weeks ago" --oneline | wc -l

# Total commits
git log --since="4 weeks ago" --oneline | wc -l
```

**Classification**:

- Elite: 0-15% revert/fix ratio
- High: 16-30%
- Medium: 16-30%
- Low: 46-60%

### Mean Time to Recovery (Proxy)

**What to check**: Time between "broken" commit and "fix" commit.

```bash
# Find pairs of commits where fix follows a revert/broken commit
# Pattern: revert X -> fix X within short window
git log --all --oneline --grep="revert\|hotfix" --since="4 weeks ago"
```

**Classification**:

- Elite: < 1 hour between revert and fix
- High: < 1 day
- Medium: 1-7 days
- Low: > 7 days

---

## Additional Metrics

### Commit Regularity

**What to check**: Days with commits vs total days.

```bash
# Unique commit dates in last 4 weeks
git log --since="4 weeks ago" --format="%ad" --date=short | sort -u | wc -l

# Total days in period
echo 28
```

**Classification**:

- Elite: commits every day (28/28 days)
- High: commits most days (21-27 days)
- Medium: commits some days (7-20 days)
- Low: infrequent commits (< 7 days)

### Bus Factor

**What to check**: Number of unique authors.

```bash
# Unique authors in last 4 weeks
git log --since="4 weeks ago" --format="%an" | sort -u | wc -l

# All-time unique authors
git log --format="%an" | sort -u | wc -l
```

**Interpretation**:

- 1: Single point of failure
- 2-3: Low bus factor
- 4-10: Healthy
- 10+: Very distributed

### Commit Message Quality

**What to check**: Percentage following conventional commits.

```bash
# Conventional commits (type(scope): description)
git log --since="4 weeks ago" --format="%s" | \
  grep -E "^(feat|fix|docs|style|refactor|test|chore|build|ci|perf|revert)(\([^)]+\))?: " | wc -l

# Total commits
git log --since="4 weeks ago" --oneline | wc -l
```

**Classification**:

- Elite: > 90% conventional
- High: 70-90%
- Medium: 50-70%
- Low: < 50%

---

## Implementation Notes

### Data Collection

The check script (`check-dora.sh`) collects data using:

1. `git log --since="4 weeks ago"` — bounded time window
2. `git log --format="%H %ai"` — full timestamp for lead time
3. `git log --format="%an"` — author names for bus factor
4. `git log --format="%s"` — subject lines for conventional commit check

### Limitations

- **Deployment frequency** is a proxy (commit count ≠ deploy count)
- **Lead time** is commit-to-commit, not commit-to-deploy
- **Change failure rate** uses revert commits as proxy for failures
- **MTTR** requires manual annotation or CI status correlation

### Correlation with Maturity

| DORA Level | cpm Maturity Level | Typical Characteristics |
|------------|-------------------|------------------------|
| Elite | 4 | Full CI/CD, trunk-based, comprehensive testing |
| High | 3 | Automated testing, regular releases, metrics |
| Medium | 2 | Some automation, documented process |
| Low | 0-1 | Manual deployments, ad-hoc process |

---

## References

- Forsgren, Nicole, et al. "Accelerate: The Science of Lean Software and DevOps"
- DORA Research Program: <https://www.devops-research.com/research.html>
- @see docs/adrs/adr-013-product-positioning.md (maturity framework)
