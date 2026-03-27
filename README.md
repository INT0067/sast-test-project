# SAST Test Project

Test project to validate SAST tools (Semgrep, GoSec, Psalm, Trivy) on PR scans.

## Structure

```
├── go-app/          # Go application
│   ├── go.mod
│   └── main.go
├── php-app/         # PHP application
│   ├── composer.json
│   ├── psalm.xml
│   └── src/
│       └── index.php
└── .github/
    └── workflows/
        └── sast.yml  # SAST scanning workflow
```

## Testing

1. Push this to GitHub as `main` branch
2. Create a new branch, add vulnerable code
3. Open a PR → SAST checks will run automatically
