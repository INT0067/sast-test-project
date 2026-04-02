# SAST PR Scanning — Complete Overview

---

## 1. What is SAST?

**Static Application Security Testing** — it scans source code for security vulnerabilities **without running the application**. It reads the code and identifies patterns that could lead to security issues like SQL injection, XSS, command injection, etc.

---

## 2. Our Requirement

| Requirement | Solution |
|---|---|
| Scan only PR changes, not full codebase | Each tool is configured to scan only changed files in the PR |
| Fully open-source, no cost | All 4 tools are free with no scan limits |
| Support PHP and Go | Covered by combining generalist + specialist tools |
| Run automatically on every PR | GitHub Actions workflow triggers on every PR |
| Block PRs with vulnerabilities | Checks fail when vulnerabilities are found |

---

## 3. Why 4 Tools Instead of 1?

No single tool catches everything. Each tool has a different detection method:

| Detection Method | Tool | What it does | Example |
|---|---|---|---|
| **Pattern Matching** | Semgrep | Looks for known dangerous code patterns | Sees `"SELECT * FROM" + variable` and flags it |
| **Go Deep Analysis** | GoSec | Understands Go language internals | Catches hardcoded credentials, crypto misuse, insecure TLS |
| **PHP Taint Analysis** | Psalm | Tracks user input through the code to dangerous functions | Traces `$_GET['id']` flowing through 3 functions into `sql.query()` |
| **Dependency Scanning** | Trivy | Checks if libraries used have known vulnerabilities | Flags if `composer.lock` has a package with a published CVE |

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
| **Output** | SARIF format — appears as annotations on PR lines in GitHub |

### Tool 2: GoSec (Go Specialist)

| Detail | Info |
|---|---|
| **License** | Apache 2.0 (open source) |
| **Cost** | Free — everything included |
| **Languages** | Go only |
| **What it catches** | Hardcoded credentials, insecure TLS, weak crypto, command injection, SQL injection, unsafe pointers, HTTP misconfigurations |
| **How it scans PR only** | Workflow detects changed `.go` files and scans only those directories |
| **Why needed** | Catches Go-specific issues Semgrep misses (hardcoded creds, crypto misuse, HTTP timeouts) |

### Tool 3: Psalm (PHP Specialist)

| Detail | Info |
|---|---|
| **License** | MIT (open source) |
| **Cost** | Free — everything included |
| **Languages** | PHP only |
| **What it catches** | SQL injection, XSS, command injection, path traversal, insecure deserialization — via **taint analysis** (tracks user input to dangerous function) |
| **How it scans PR only** | Workflow detects changed `.php` files and scans only those |
| **Why needed** | Follows data flow across functions/files — catches vulnerabilities Semgrep's pattern matching misses in complex code |

### Tool 4: Trivy (Dependency Scanner)

| Detail | Info |
|---|---|
| **License** | Apache 2.0 (open source) |
| **Cost** | Free — everything included |
| **Languages** | PHP (composer), Go (go.sum), and many others |
| **What it catches** | Known CVEs in third-party libraries/packages |
| **How it scans PR only** | Only runs when `go.sum`, `go.mod`, `composer.lock`, or `composer.json` changes |
| **Why needed** | None of the other 3 tools check dependencies — this is a completely different attack surface |

---

## 5. Cost Comparison

| Tool | Our Choice (Open Source) | Paid Alternative | Paid Cost |
|---|---|---|---|
| Semgrep OSS | Free, unlimited | Semgrep Cloud Platform | $40+/developer/month |
| GoSec | Free, unlimited | Snyk | $25+/developer/month |
| Psalm | Free, unlimited | SonarQube Developer | $150+/year |
| Trivy | Free, unlimited | Snyk Container | $25+/developer/month |
| **Total** | **$0** | — | **$100+/developer/month** |

---

## 6. What Vulnerabilities Are Covered?

| Vulnerability Type (OWASP Top 10) | Semgrep | GoSec | Psalm | Trivy |
|---|---|---|---|---|
| A01 — Broken Access Control | Partial | — | — | — |
| A02 — Cryptographic Failures | Go + PHP | Go (deep) | — | — |
| A03 — Injection (SQLi, XSS, CMDi) | Go + PHP | Go (deep) | PHP (deep) | — |
| A04 — Insecure Design | — | — | — | — |
| A05 — Security Misconfiguration | Go + PHP | Go (deep) | — | — |
| A06 — Vulnerable Components | — | — | — | Go + PHP |
| A07 — Auth Failures | Partial | Go | — | — |
| A08 — Data Integrity (Deserialization) | PHP | — | PHP (deep) | — |
| A09 — Logging Failures | — | — | — | — |
| A10 — SSRF | Partial | — | PHP | — |

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

| Vulnerability | Semgrep | Psalm | Detected? |
|---|---|---|---|
| SQL Injection | 1 alert | **Missed** | Yes (Semgrep saved it) |
| XSS | 1 alert | 2 alerts | Yes |
| Command Injection | 3 alerts | 1 alert | Yes |
| Path Traversal | 1 alert | 1 alert | Yes |
| Hardcoded Credentials | **Missed** | N/A | **Not detected** |
| Insecure Deserialization | 1 alert | 1 alert | Yes |

**Detection rate: 10 out of 11 (91%)** — only PHP hardcoded credentials missed.

**Key insight**: Using Semgrep alone would have missed 2 vulnerabilities. The multi-tool approach caught them.

---

## 8. How It Works in Practice

```
Developer creates PR
        |
        v
GitHub Actions triggers automatically
        |
        |-- Semgrep ------> scans all changed PHP + Go files (pattern matching)
        |-- GoSec --------> scans changed Go files (deep Go analysis)
        |-- Psalm --------> scans changed PHP files (taint analysis)
        |-- Trivy --------> scans if dependency files changed (CVE check)
        |
        v
Results appear as:
  |-- Annotations on exact lines in PR diff
  |-- Failed checks blocking the PR merge
  |-- Developers see what to fix and why
        |
        v
Developer fixes issues -> pushes -> checks re-run -> PR can be merged
```

---

## 9. Developer Experience

- Developer sees **exact line** with the error on the PR
- Each finding includes **what's wrong** and **how to fix it**
- No manual setup — runs automatically on every PR
- Scan takes **30-60 seconds** — fast feedback
- Only shows issues in **their changes** — no noise from existing code

---

## 10. Errors Found & How to Fix Them

### Go Errors & Fixes

**1. SQL Injection**
```go
// ERROR: user input directly concatenated into SQL query
query := "SELECT * FROM users WHERE id = " + userID
rows, _ := db.Query(query)

// FIX: use parameterized query with ? placeholder
query := "SELECT * FROM users WHERE id = ?"
rows, _ := db.Query(query, userID)
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

## 11. What This Does NOT Cover

| Gap | Reason | Mitigation |
|---|---|---|
| PHP hardcoded credentials | No tool in our stack detects this reliably | Use secret scanning (GitHub has built-in secret scanning for free) |
| Runtime vulnerabilities | SAST is static — doesn't run the code | Consider DAST (Dynamic Testing) for staging environments |
| Business logic flaws | Tools can't understand business rules | Code review by humans |
| Infrastructure misconfig | Not code-level | Use Terraform/IaC scanning if applicable |

---

## 12. Maintenance Required

| Task | Frequency | Effort |
|---|---|---|
| Workflow file updates | Rare — only for tool version bumps | 5 minutes |
| False positive tuning | First 2-4 weeks after deployment | Add `# nosec` or `.semgrepignore` rules |
| Rule updates | Automatic — Semgrep community rules update themselves | Zero |
| Monitoring | Check if checks are running on PRs | Minimal |

---

## 13. Rollout Plan

| Phase | Action | Timeline |
|---|---|---|
| 1 | Deploy workflow to company repo | Day 1 |
| 2 | Run in **warning mode** (don't block PRs) | Week 1-2 |
| 3 | Tune false positives | Week 2-4 |
| 4 | Enable **blocking mode** (PRs can't merge with vulnerabilities) | Week 4+ |

---

## 14. Common Questions

**Q: Why not just use one tool like SonarQube?**
A: SonarQube Community edition doesn't support PR-scoped scanning (that's a paid feature). Our 4-tool stack is free and has better combined detection than any single tool.

**Q: Will this slow down developers?**
A: No. All 4 tools run in parallel and complete in 30-60 seconds. Developers get instant feedback.

**Q: What about false positives?**
A: Expected in the first 2-4 weeks. We can tune with ignore rules. Better to have a false positive than miss a real vulnerability.

**Q: Is this production-ready?**
A: Yes. We tested with 11 planted vulnerabilities and caught 10 (91%). All tools are widely used in the industry (Semgrep: 10K+ GitHub stars, Trivy: 20K+ stars).

**Q: What's the ongoing cost?**
A: $0. Only cost is GitHub Actions minutes, which are free for public repos and included in GitHub plans for private repos.

**Q: Can we add more languages later?**
A: Yes. Semgrep supports 30+ languages. Just add language-specific specialist tools as needed.

---

## 15. Test Project Reference

- **GitHub Repository**: https://github.com/INT0067/sast-test-project
- **Test PR with vulnerabilities**: https://github.com/INT0067/sast-test-project/pull/1
- **Workflow file**: `.github/workflows/sast.yml`
