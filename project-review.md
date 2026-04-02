# SAST PR Scanning — Complete Overview

---

## 1. What is SAST?

**Static Application Security Testing (SAST)** — it scans source code for security vulnerabilities **without running the application**. It reads the code and identifies patterns that could lead to security issues like SQL injection, XSS, command injection, etc.

Think of it like a spell-checker, but for security — it reads your code and flags dangerous patterns.

---

## 2. Our Requirement

| Requirement | Solution |
|---|---|
| Scan only PR changes, not full codebase | Each tool is configured to scan only changed files in the PR |
| Fully open-source, no cost | Both tools are free with no scan limits |
| Support PHP and Go | Semgrep covers both, GoSec adds deep Go analysis |
| Run automatically on every PR | GitHub Actions workflow with self-hosted runner |
| Block PRs with vulnerabilities | Check fails when vulnerabilities are found |
| No data leaves our infrastructure | Self-hosted runner runs on our own server |

---

## 3. Why 2 Tools Instead of 1?

No single tool catches everything. Each tool has a different detection method:

| Detection Method | Tool | What it does | Example |
|---|---|---|---|
| **Pattern Matching** | Semgrep | Looks for known dangerous code patterns in PHP + Go | Sees `"SELECT * FROM" + variable` and flags it |
| **Go Deep Analysis** | GoSec | Understands Go language internals | Catches hardcoded credentials, crypto misuse, insecure TLS that Semgrep misses |

Using Semgrep alone catches ~70% of Go issues. Adding GoSec pushes it to ~95%. For PHP, Semgrep alone is sufficient.

---

## 4. Tool Details

### Tool 1: Semgrep (Generalist — PHP + Go)

| Detail | Info |
|---|---|
| **License** | LGPL-2.1 (open source) |
| **Cost** | Free — OSS engine + community rules, no account needed |
| **Languages** | PHP, Go (and 30+ others) |
| **What it catches** | SQL injection, XSS, command injection, insecure deserialization, path traversal, secrets in code |
| **How it scans PR only** | Built-in `--baseline-commit` flag — only reports NEW findings in the PR diff |
| **Rules** | 3000+ community rules, always updated automatically |

### Tool 2: GoSec (Go Specialist)

| Detail | Info |
|---|---|
| **License** | Apache 2.0 (open source) |
| **Cost** | Free — everything included |
| **Languages** | Go only |
| **What it catches** | Hardcoded credentials, insecure TLS, weak crypto, command injection, SQL injection, unsafe pointers, HTTP misconfigurations |
| **How it scans PR only** | Workflow detects changed `.go` files and scans only those directories |
| **Why needed** | Catches Go-specific issues Semgrep misses (hardcoded creds, crypto misuse, HTTP timeouts) |

---

## 5. Cost Comparison

| Tool | Our Choice (Open Source) | Paid Alternative | Paid Cost |
|---|---|---|---|
| Semgrep OSS | Free, unlimited | Semgrep Cloud Platform | $40+/developer/month |
| GoSec | Free, unlimited | Snyk | $25+/developer/month |
| **Total** | **$0** | — | **$65+/developer/month** |

For comparison, SonarQube (the most common alternative) charges $150+/year for its paid edition, and the free Community edition does NOT support PR-scoped scanning.

---

## 6. What Vulnerabilities Are Covered?

| Vulnerability Type (OWASP Top 10) | Semgrep | GoSec |
|---|---|---|
| A01 — Broken Access Control | Partial | — |
| A02 — Cryptographic Failures | Go + PHP | Go (deep) |
| A03 — Injection (SQLi, XSS, CMDi) | Go + PHP | Go (deep) |
| A04 — Insecure Design | — | — |
| A05 — Security Misconfiguration | Go + PHP | Go (deep) |
| A06 — Vulnerable Components | — | — |
| A07 — Auth Failures | Partial | Go |
| A08 — Data Integrity (Deserialization) | PHP | — |
| A09 — Logging Failures | — | — |
| A10 — SSRF | Partial | — |

---

## 7. Test Results (Proof of Concept)

We tested with **11 intentionally planted vulnerabilities** (5 Go + 6 PHP):

### Go Results

| Vulnerability | Semgrep | GoSec | Detected? |
|---|---|---|---|
| SQL Injection | 3 alerts | 2 alerts | Yes |
| Command Injection | 1 alert | 2 alerts | Yes |
| Hardcoded Credentials | **Missed** | 1 alert | Yes (GoSec saved it) |
| Insecure TLS | 2 alerts | 1 alert | Yes |
| Weak Crypto (MD5) | 1 alert | 2 alerts | Yes |

### PHP Results

| Vulnerability | Semgrep | Detected? |
|---|---|---|
| SQL Injection | 1 alert | Yes |
| XSS | 1 alert | Yes |
| Command Injection | 3 alerts | Yes |
| Path Traversal | 1 alert | Yes |
| Hardcoded Credentials | **Missed** | Not detected |
| Insecure Deserialization | 1 alert | Yes |

**Detection rate: 10 out of 11 (91%)** — only PHP hardcoded credentials missed.

**Key insight**: Using Semgrep alone would have missed Go hardcoded credentials. GoSec caught it.

---

## 8. How It Works in Practice

```
Developer opens/updates a PR
        |
        v
Self-hosted runner on our server picks up the job automatically
        |
        v
Semgrep scans changed PHP + Go files (pattern matching)
GoSec scans changed Go files (deep analysis)
        |
        v
Results appear as:
  - PR comment with summary table (file, line, rule, severity)
  - Annotations on exact code lines in "Files changed" tab
  - Check fails -> PR merge is blocked
        |
        v
Developer fixes code -> pushes -> scan re-runs automatically -> if clean -> merge allowed
```

---

## 9. What Developers See on a PR

1. **Check fails** — red X on the PR, merge is blocked
2. **PR comment** — table listing every vulnerability with file, line, rule, severity, description
3. **Annotations** — errors shown directly on the vulnerable code lines in "Files changed" tab
4. **Comment updates** — same comment gets updated on every push, no spam
5. **Each error tells** what's wrong and how to fix it

**Developer needs to install:** Nothing
**Developer needs to configure:** Nothing
**Developer needs to learn:** Nothing — they just read the error on their PR and fix it
**Scan time:** 30-60 seconds

---

## 10. Self-Hosted Runner — How It Keeps Data In-House

All scans run on **our own server** using a GitHub self-hosted runner. No code is processed on GitHub's servers.

| Concern | Answer |
|---|---|
| Where does the scan run? | On our server |
| Does our code leave our infrastructure? | No — code is already on GitHub (we host there), scanning happens on our machine |
| Do Semgrep/GoSec send data anywhere? | No — they are offline tools, no internet needed during scan |
| What does GitHub see? | Only the PR comment text and check pass/fail status |
| What if the runner goes down? | PR checks won't run — PRs can't be merged until runner is back (safe default) |
| Can a developer bypass the scan? | No — the check is automatic, they can't skip it |

---

## 11. Errors Found & How to Fix Them

### Go Errors & Fixes

**1. SQL Injection**
```go
// ERROR: user input directly concatenated into SQL query
query := "SELECT * FROM users WHERE id = " + userID
rows, _ := db.Query(query)

// FIX: use parameterized query with ? placeholder
rows, _ := db.Query("SELECT * FROM users WHERE id = ?", userID)
```

**2. Command Injection**
```go
// ERROR: user input passed to shell directly — attacker can inject commands
cmd := exec.Command("sh", "-c", "ping -c 1 "+host)

// FIX: pass arguments directly, no shell involved
cmd := exec.Command("ping", "-c", "1", host)
```

**3. Hardcoded Credentials**
```go
// ERROR: secrets visible in source code
dbPassword = "SuperSecret123!"
apiKey     = "AKIAIOSFODNN7EXAMPLE"

// FIX: read from environment variables
dbPassword = os.Getenv("DB_PASSWORD")
apiKey     = os.Getenv("API_KEY")
```

**4. Insecure TLS**
```go
// ERROR: skips certificate verification — allows man-in-the-middle attacks
TLSClientConfig: &tls.Config{InsecureSkipVerify: true}

// FIX: remove InsecureSkipVerify, set minimum TLS version
TLSClientConfig: &tls.Config{MinVersion: tls.VersionTLS13}
```

**5. Weak Crypto (MD5)**
```go
// ERROR: MD5 is broken — collisions can be generated
h := md5.Sum([]byte(password))

// FIX: use SHA256
h := sha256.Sum256([]byte(password))
```

### PHP Errors & Fixes

**1. SQL Injection**
```php
// ERROR: user input joined directly into SQL query
$query = "SELECT * FROM users WHERE id = " . $_GET['id'];
$stmt = $pdo->query($query);

// FIX: use prepared statement with ? placeholder
$stmt = $pdo->prepare("SELECT * FROM users WHERE id = ?");
$stmt->execute([$_GET['id']]);
```

**2. XSS (Cross-Site Scripting)**
```php
// ERROR: user input printed directly in HTML — attacker can inject <script> tags
echo "<h1>Welcome, " . $_POST['name'] . "</h1>";

// FIX: escape with htmlentities()
echo "<h1>Welcome, " . htmlentities($_POST['name'], ENT_QUOTES, 'UTF-8') . "</h1>";
```

**3. Command Injection**
```php
// ERROR: user input passed directly to shell
$output = shell_exec("ping -c 1 " . $_GET['host']);

// FIX: escape the argument with escapeshellarg()
$output = shell_exec("ping -c 1 " . escapeshellarg($_GET['host']));
```

**4. Path Traversal**
```php
// ERROR: user can send ../../etc/passwd to read any file
$content = file_get_contents("/var/www/uploads/" . $_GET['file']);

// FIX: use basename() to strip directory traversal
$content = file_get_contents("/var/www/uploads/" . basename($_GET['file']));
```

**5. Hardcoded Credentials**
```php
// ERROR: password visible in source code
$password = "admin123";

// FIX: read from environment variable
$password = getenv('DB_PASSWORD');
```

**6. Insecure Deserialization**
```php
// ERROR: unserialize() on user data can execute arbitrary code
return unserialize($_COOKIE['session_data']);

// FIX: use json_decode() — JSON cannot contain executable code
return json_decode($_COOKIE['session_data'], true);
```

---

## 12. What SAST Does NOT Cover

| Gap | Reason | Mitigation |
|---|---|---|
| PHP hardcoded credentials | No tool in our stack detects this reliably | GitHub has built-in secret scanning (free) |
| Runtime vulnerabilities | SAST is static — doesn't run the code | Consider DAST (Dynamic Testing) for staging |
| Business logic flaws | Tools can't understand business rules | Code review by humans |
| Syntax/logic bugs (wrong if/else) | SAST only checks security, not correctness | Unit tests, code review |
| Dependency CVEs | Not covered by Semgrep/GoSec | Can add Trivy later if needed (free) |
| Infrastructure misconfig | Not code-level | Use Terraform/IaC scanning if applicable |

---

## 13. Comparison with SonarQube

| Feature | Our Setup (Semgrep + GoSec) | SonarQube Community | SonarQube Paid |
|---|---|---|---|
| Cost | **Free** | Free | $150+/year |
| PR-scoped scanning | **Yes** | **No** | Yes |
| Go support | **Deep** (GoSec) | Basic | Basic |
| PHP support | **Good** (Semgrep) | Good | Good |
| Self-hosted | **Yes** | Yes | Yes |
| Setup time | **30 minutes** | 2-4 hours | 2-4 hours |
| Maintenance | **Minimal** | Database + server | Database + server |
| PR comments | **Yes** | No | Yes |
| Code annotations | **Yes** | No | Yes |

---

## 14. Deployment Steps for Organization

| Step | Action | Who | Effort |
|---|---|---|---|
| 1 | Install tools on server: `pip3 install semgrep`, `go install gosec@latest` | DevOps | 15 minutes |
| 2 | Set up self-hosted runner on server | DevOps | 10 minutes |
| 3 | Copy `.github/workflows/sast.yml` to org repo | DevOps | 2 minutes |
| 4 | Done — every PR gets scanned automatically | — | Zero |

### What's needed on the server:

| Tool | Install command |
|---|---|
| Go | `sudo apt install golang-go` |
| Semgrep | `pip3 install semgrep` |
| GoSec | `go install github.com/securego/gosec/v2/cmd/gosec@latest` |
| GitHub CLI | `sudo apt install gh` |
| Self-hosted Runner | Download from GitHub Settings |

### Rollout Plan

| Phase | Action | Timeline |
|---|---|---|
| 1 | Deploy workflow to one repo | Day 1 |
| 2 | Run in **warning mode** (don't block PRs) | Week 1-2 |
| 3 | Tune false positives | Week 2-4 |
| 4 | Enable **blocking mode** (PRs can't merge with vulnerabilities) | Week 4+ |
| 5 | Roll out to all repos | Week 5+ |

---

## 15. Maintenance Required

| Task | Frequency | Effort |
|---|---|---|
| Workflow file updates | Rare — only for tool version bumps | 5 minutes |
| False positive tuning | First 2-4 weeks after deployment | Add `// nosec` or `.semgrepignore` rules |
| Rule updates | Automatic — Semgrep community rules update themselves | Zero |
| Runner monitoring | Check if runner is alive | Minimal |

---

## 16. Common Questions

**Q: Why not just use one tool like SonarQube?**
A: SonarQube Community edition doesn't support PR-scoped scanning (that's a paid feature). Our setup does it for free and has better Go coverage with GoSec.

**Q: Will this slow down developers?**
A: No. Scan takes 30-60 seconds and runs in the background. Developers continue working.

**Q: What about false positives?**
A: Expected in the first 2-4 weeks. We can tune with ignore rules. Better a false positive than a missed vulnerability.

**Q: Is our code safe?**
A: Yes. Everything runs on our own server via self-hosted runner. No code is sent to any third-party service.

**Q: Can someone ignore the warnings?**
A: No. The PR check fails and merge is blocked. They must fix the issues first.

**Q: What's the ongoing cost?**
A: $0. Both tools are open source. The only cost is the server running the self-hosted runner, which we already have.

**Q: Can we add more languages later?**
A: Yes. Semgrep supports 30+ languages. Just add language-specific specialist tools as needed.

**Q: Does it catch logic bugs like wrong if/else conditions?**
A: No. SAST only catches security vulnerabilities. Logic bugs are caught by unit tests and code reviews.

**Q: What if the runner goes down?**
A: PR checks won't run, so PRs can't be merged. This is a safe default. Just restart the runner.

---

## 17. Test Project Reference

- **GitHub Repository**: https://github.com/INT0067/sast-test-project
- **Test PR with vulnerabilities**: https://github.com/INT0067/sast-test-project/pull/2
- **Workflow file**: `.github/workflows/sast.yml`
- **Self-hosted runner**: `~/actions-runner` on the server
