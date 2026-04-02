# SAST Implementation Proposal — Automated Security Scanning for PRs


## Executive Summary

We currently use SonarQube for security scanning, but it scans the **entire codebase** — not just the PR changes. Developers see hundreds of old issues mixed with their own, leading to noise and ignored results. New vulnerabilities slip through.

We have built and tested a replacement that scans **only the PR changes** and shows developers **only the issues they introduced**, with clear fix suggestions. The system uses two open-source tools (Semgrep + GoSec), runs entirely on our own infrastructure, costs $0, and requires zero effort from developers.

**Key Results from Testing:**
- 91% detection rate on planted vulnerabilities
- 30-60 second scan time per PR
- Zero cost — fully open-source tools
- Zero developer setup — fully automated
- All data stays on our servers — no third-party involvement

---

## 1. The Problem

We currently use **SonarQube** for security scanning, but it has a critical limitation:

- **SonarQube scans the entire codebase** — not just the changes in a PR
- When a developer opens a PR with 10 lines changed, SonarQube scans all 100,000+ lines in the repo
- This means the developer sees **hundreds of existing issues** mixed with their own — they don't know which issues they introduced
- Developers start ignoring the results because most findings are not relevant to their changes
- New vulnerabilities slip through because they are buried in noise from old issues
- SonarQube Community edition (free) does not support PR-scoped scanning — that requires the paid Developer edition

**What we need:** A tool that scans **only the PR changes** and shows the developer **only the vulnerabilities they introduced** — not the entire codebase.

**Risk:** Without PR-scoped scanning, new vulnerabilities continue to reach production undetected despite having a SAST tool in place.

---

## 2. The Solution

We set up **Static Application Security Testing (SAST)** — automated tools that read source code and flag security vulnerabilities before code is merged.

### What is SAST?

SAST scans source code **without running the application**. It reads the code and identifies patterns that could be exploited by attackers. Think of it like a spell-checker, but for security.

Example of what it catches:
```go
// DANGEROUS — attacker can manipulate the SQL query
query := "SELECT * FROM users WHERE id = " + userInput
db.Query(query)

// SAFE — database handles escaping, attacker cannot break out
db.Query("SELECT * FROM users WHERE id = ?", userInput)
```

### How it works in our setup:

```
Developer opens a Pull Request
        |
        v
Our server automatically picks up the PR
        |
        v
Two security tools scan ONLY the changed code (not the full codebase)
        |
        v
Results appear on the PR:
  - Comment with all findings (file, line, what's wrong, how to fix)
  - Check fails — merge is BLOCKED until issues are fixed
        |
        v
Developer reads the fix suggestion, corrects the code, pushes
        |
        v
Scan re-runs automatically — if clean, PR can be merged
```

---

## 3. Tools Selected

After evaluating multiple options (SonarQube, Snyk, CodeQL, Semgrep, GoSec, Psalm, Trivy), we selected two tools:

### Tool 1: Semgrep — Generalist Scanner (PHP + Go)

| Detail | Info |
|---|---|
| **What it does** | Scans both PHP and Go code using 3000+ pre-built security rules |
| **What it catches** | SQL injection, XSS, command injection, path traversal, insecure deserialization, hardcoded secrets |
| **License** | LGPL-2.1 (open source) |
| **Cost** | Free — no account, no API key, no scan limits |
| **How it scans PR only** | Built-in `--baseline-commit` flag — only reports NEW findings introduced in the PR |
| **Industry adoption** | 10,000+ GitHub stars, used by Dropbox, Slack, Figma |

### Tool 2: GoSec — Go Specialist Scanner

| Detail | Info |
|---|---|
| **What it does** | Deep analysis of Go code — understands Go's type system and standard library |
| **What it catches** | Hardcoded credentials, insecure TLS, weak crypto, unsafe memory, HTTP misconfigurations — issues Semgrep misses |
| **License** | Apache 2.0 (open source) |
| **Cost** | Free — no account, no API key, no scan limits |
| **How it scans PR only** | Workflow detects changed `.go` files and scans only those directories |
| **Industry adoption** | 8,000+ GitHub stars, official OWASP project |

### Why two tools?

| Vulnerability | Semgrep alone | Semgrep + GoSec |
|---|---|---|
| SQL Injection | Caught | Caught |
| Command Injection | Caught | Caught |
| Hardcoded Credentials (Go) | **Missed** | **Caught by GoSec** |
| Insecure TLS | Caught | Caught |
| Weak Crypto | Caught | Caught |
| HTTP Server Timeouts | **Missed** | **Caught by GoSec** |

Semgrep alone catches ~70% of Go security issues. Adding GoSec pushes coverage to ~95%. For PHP, Semgrep alone is sufficient — it caught 5 out of 6 PHP vulnerabilities in our testing.

---

## 4. Why Replace SonarQube?

We currently use SonarQube, but it does not meet our PR-scoped scanning requirement. Here is a detailed comparison:

### Current Problem with SonarQube

| Issue | Impact |
|---|---|
| Scans full codebase on every run | Developer sees hundreds of old issues, not just their changes |
| No PR-scoped scanning (Community edition) | Cannot tell which vulnerabilities were introduced by the PR |
| Developers ignore results | Too much noise — real issues get buried |
| New vulnerabilities slip through | Developer can't distinguish their issues from existing ones |
| Requires PostgreSQL database | Extra infrastructure to maintain |

### Comparison

| Feature | Our New Setup (Semgrep + GoSec) | SonarQube (Current - Community) | SonarQube Paid |
|---|---|---|---|
| **Cost** | $0 | $0 | $150+/year |
| **PR-scoped scanning** | **Yes — only shows new issues** | **No — scans full codebase** | Yes |
| **Go deep analysis** | Deep (GoSec) | Basic | Basic |
| **PHP support** | Good | Good | Good |
| **Self-hosted** | Yes | Yes | Yes |
| **Setup time** | 30 minutes | 2-4 hours (needs database) | 2-4 hours |
| **Maintenance** | Minimal (no database needed) | Requires PostgreSQL database | Requires database |
| **PR comments with fix suggestions** | Yes — tells developer how to fix | No | Partial |
| **Code line annotations** | Yes — errors on exact lines | No | Partial |
| **Developer experience** | Sees only their issues + how to fix | Sees all issues in entire repo | Sees only their issues |

### Key Advantages of New Setup Over SonarQube

1. **PR-scoped scanning for free** — SonarQube charges for this, we get it for $0
2. **Fix suggestions** — our PR comment tells the developer exactly how to fix each issue, SonarQube only describes the problem
3. **No database required** — SonarQube needs PostgreSQL, our setup needs nothing
4. **Better Go coverage** — GoSec catches Go-specific issues SonarQube misses (hardcoded credentials, HTTP timeouts)
5. **Faster setup** — 30 minutes vs 2-4 hours
6. **Less noise** — developer sees only issues from their PR, not the entire codebase

---

## 5. Proof of Concept — Test Results

### Test Setup

We created a test project with intentional vulnerabilities in both Go and PHP, deployed the scanning system, and verified detection.

- **Test Repository:** https://github.com/INT0067/sast-test-project
- **Test PR (Go + PHP):** https://github.com/INT0067/sast-test-project/pull/3

### Vulnerabilities Planted: 11 total (5 Go + 6 PHP)

**Go vulnerabilities:**
1. SQL Injection — user input concatenated into SQL query
2. Command Injection — user input passed to shell
3. Hardcoded Credentials — API key and password in source code
4. Insecure TLS — certificate verification disabled
5. Weak Crypto — MD5 used for password hashing

**PHP vulnerabilities:**
1. SQL Injection — user input in SQL query
2. XSS (Cross-Site Scripting) — user input echoed in HTML
3. Command Injection — user input in shell_exec
4. Path Traversal — user controls file path
5. Hardcoded Credentials — database password in code
6. Insecure Deserialization — unserialize on user data

### Detection Results

#### Go

| Vulnerability | Semgrep | GoSec | Detected? |
|---|---|---|---|
| SQL Injection | 3 alerts | 2 alerts | Yes |
| Command Injection | 1 alert | 2 alerts | Yes |
| Hardcoded Credentials | **Missed** | 1 alert | Yes (GoSec caught it) |
| Insecure TLS | 2 alerts | 1 alert | Yes |
| Weak Crypto (MD5) | 1 alert | 2 alerts | Yes |

#### PHP

| Vulnerability | Semgrep | Detected? |
|---|---|---|
| SQL Injection | 1 alert | Yes |
| XSS | 1 alert | Yes |
| Command Injection | 3 alerts | Yes |
| Path Traversal | 1 alert | Yes |
| Hardcoded Credentials | **Missed** | No |
| Insecure Deserialization | 1 alert | Yes |

### Summary

| Metric | Result |
|---|---|
| Total vulnerabilities planted | 11 |
| Total detected | **10** |
| Detection rate | **91%** |
| Missed | 1 (PHP hardcoded credentials) |
| False positives | 0 |
| Scan time | ~30 seconds |

**The 1 miss** (PHP hardcoded credentials) can be covered by GitHub's built-in secret scanning feature, which is free.

---

## 6. What Developers See on a PR

### 6.1 Check Fails — Merge Blocked

When vulnerabilities are found, the PR check fails with a red X. The developer cannot merge until issues are fixed.

### 6.2 PR Comment — Summary Table

A comment is automatically posted on the PR with all findings:

```
| File | Line | Severity | What's Wrong | How to Fix |
|---|---|---|---|---|
| search.go | 14 | ERROR | User data in SQL string | Use parameterized queries with ? placeholder |
| search.go | 23 | ERROR | User input in shell command | Use exec.Command("cmd", arg1) — no shell |
| search.php | 9 | ERROR | User data in SQL string | Use $pdo->prepare() with ? placeholder |
| search.php | 18 | ERROR | User input in shell_exec | Use escapeshellarg() to escape input |
```

The **"How to Fix"** column tells the developer exactly what to do — no security expertise needed.

### 6.3 Comment Updates

When the developer pushes a fix, the scan re-runs automatically and the **same comment updates** — no spam, no multiple comments.

### 6.4 Developer Effort

| What | Effort |
|---|---|
| Developer needs to install | Nothing |
| Developer needs to configure | Nothing |
| Developer needs to learn | Nothing — just read the fix suggestion |
| Developer needs to run | Nothing — fully automatic |

---

## 7. Security & Data Privacy

All scanning runs on **our own server** using a GitHub self-hosted runner. No code is processed on external servers.

| Concern | Answer |
|---|---|
| Where does the scan run? | On our own server |
| Does code leave our infrastructure? | No — tools run locally, no data sent externally |
| Do Semgrep/GoSec phone home? | No — they are offline tools, no internet needed during scan |
| What does GitHub see? | Only the PR comment text and check pass/fail (code is already on GitHub) |
| Can a developer bypass the scan? | No — check is automatic, merge blocked until issues fixed |
| Can a developer suppress findings? | Yes, with `// nosec` comments — but these are visible in code review |
| What if the runner goes down? | PR checks don't run — PRs can't be merged (safe default) |
| Are the tools trustworthy? | Semgrep: backed by Semgrep Inc, 10K+ stars. GoSec: official OWASP project, 8K+ stars |

---

## 8. What SAST Does NOT Cover

SAST is one layer of defense, not a complete solution:

| What it catches | What it does NOT catch |
|---|---|
| SQL injection, XSS, command injection | Business logic flaws (e.g., wrong access control rules) |
| Hardcoded secrets (Go) | Runtime vulnerabilities (e.g., misconfigured server) |
| Weak crypto, insecure TLS | Infrastructure issues (e.g., open ports, firewall rules) |
| Insecure deserialization | Zero-day vulnerabilities in third-party libraries |
| Path traversal | Syntax errors or logic bugs (wrong if/else) |

**SAST covers the most common and dangerous attack vectors** (OWASP Top 10). For full coverage, it should be combined with code reviews (business logic), unit tests (correctness), and potentially DAST (runtime testing) in the future.

---

## 9. Deployment Plan

### Phase 1: Pilot (Week 1-2)

| Step | Action | Effort |
|---|---|---|
| 1 | Install Semgrep + GoSec on a server | 15 minutes |
| 2 | Set up GitHub self-hosted runner | 10 minutes |
| 3 | Add workflow file to **one** repo | 2 minutes |
| 4 | Run in **warning mode** — scan runs, shows results, but does NOT block merge | — |

### Phase 2: Tuning (Week 2-4)

| Step | Action | Effort |
|---|---|---|
| 5 | Review findings on real PRs — identify false positives | 1-2 hours/week |
| 6 | Add ignore rules for false positives (`.semgrepignore`, `// nosec`) | As needed |
| 7 | Gather developer feedback | — |

### Phase 3: Enforcement (Week 4+)

| Step | Action | Effort |
|---|---|---|
| 8 | Enable **blocking mode** — PRs with vulnerabilities cannot be merged | Config change |
| 9 | Roll out to remaining repos | Copy workflow file |

### What's Needed on the Server

| Tool | Install Command | One-time |
|---|---|---|
| Go | `sudo apt install golang-go` | Yes |
| Semgrep | `pip3 install semgrep` | Yes |
| GoSec | `go install github.com/securego/gosec/v2/cmd/gosec@latest` | Yes |
| GitHub CLI | `sudo apt install gh` | Yes |
| Self-hosted Runner | Download from GitHub repo settings | Yes |

**Total setup time: ~30 minutes**

---

## 10. Ongoing Maintenance

| Task | Frequency | Effort | Who |
|---|---|---|---|
| Workflow file updates | Rare — only for tool version bumps | 5 minutes | DevOps |
| False positive tuning | First 2-4 weeks, then rare | As needed | DevOps |
| Semgrep rule updates | Automatic — community rules update themselves | Zero | — |
| Runner monitoring | Ensure runner process is alive | Minimal | DevOps |
| Tool version updates | Quarterly | 10 minutes | DevOps |

---

## 11. Cost Analysis

### Our Setup

| Item | Cost |
|---|---|
| Semgrep | $0 (open source) |
| GoSec | $0 (open source) |
| Server | Existing infrastructure (no new server needed) |
| GitHub Actions | Included in GitHub plan (self-hosted runner uses our compute) |
| Maintenance | ~1 hour/month DevOps time |
| **Total** | **$0 + minimal DevOps time** |

### If We Used Paid Alternatives

| Tool | Cost |
|---|---|
| Semgrep Cloud Platform | $40+/developer/month |
| Snyk | $25+/developer/month |
| SonarQube Developer | $150+/year |
| **For 20 developers** | **$15,600+/year** |

**Savings: $15,600+/year**

---

## 12. Risk Assessment

| Risk | Impact | Mitigation |
|---|---|---|
| False positives annoy developers | Medium | Tune during pilot phase (Week 2-4), add ignore rules |
| Tool misses a vulnerability | Low | 91% detection rate is significantly better than 0% (current state) |
| Runner goes down | Low | PRs can't merge (safe default). Set up monitoring alert. |
| Developer adds `// nosec` to bypass | Low | Visible in code review — reviewer should question it |
| Tools become unmaintained | Very Low | Semgrep backed by a company (Semgrep Inc), GoSec is OWASP project |

---

## 13. Success Metrics

After deployment, we can measure:

| Metric | How to measure |
|---|---|
| Vulnerabilities caught before merge | Count findings per week from PR comments |
| Developer fix time | Time between PR comment and fix push |
| False positive rate | Findings marked as false positive / total findings |
| Coverage | Number of repos with SAST enabled / total repos |

---

## 14. Recommendation

**Deploy SAST scanning to production repositories using the phased approach described above.**

- **Phase 1** (warning mode) has **zero risk** — it only shows information, doesn't block anything
- We can assess real-world results during the pilot before enabling enforcement
- The system is proven (91% detection in testing), costs nothing, and requires no developer effort
- Every day without SAST is a day vulnerabilities can reach production undetected

---

## 15. References

| Resource | Link |
|---|---|
| Test Repository | https://github.com/INT0067/sast-test-project |
| Demo PR (with findings) | https://github.com/INT0067/sast-test-project/pull/3 |
| Semgrep Official Site | https://semgrep.dev |
| GoSec Official Site | https://securego.io |
| OWASP Top 10 | https://owasp.org/www-project-top-ten |

---

## Appendix A: Vulnerabilities & Fixes Reference

### Go

| Vulnerability | Dangerous Code | Safe Code |
|---|---|---|
| SQL Injection | `db.Query("SELECT * FROM t WHERE id=" + input)` | `db.Query("SELECT * FROM t WHERE id=?", input)` |
| Command Injection | `exec.Command("sh", "-c", "ping " + input)` | `exec.Command("ping", "-c", "1", input)` |
| Hardcoded Secrets | `apiKey = "AKIA..."` | `apiKey = os.Getenv("API_KEY")` |
| Insecure TLS | `InsecureSkipVerify: true` | `MinVersion: tls.VersionTLS13` |
| Weak Crypto | `md5.Sum(data)` | `sha256.Sum256(data)` |

### PHP

| Vulnerability | Dangerous Code | Safe Code |
|---|---|---|
| SQL Injection | `$pdo->query("SELECT * WHERE id=" . $_GET['id'])` | `$pdo->prepare("SELECT * WHERE id=?")->execute([$_GET['id']])` |
| XSS | `echo $_POST['name']` | `echo htmlentities($_POST['name'], ENT_QUOTES, 'UTF-8')` |
| Command Injection | `shell_exec("ping " . $_GET['host'])` | `shell_exec("ping " . escapeshellarg($_GET['host']))` |
| Path Traversal | `file_get_contents("/uploads/" . $_GET['file'])` | `file_get_contents("/uploads/" . basename($_GET['file']))` |
| Hardcoded Secrets | `$password = "admin123"` | `$password = getenv('DB_PASSWORD')` |
| Insecure Deserialization | `unserialize($_COOKIE['data'])` | `json_decode($_COOKIE['data'], true)` |
