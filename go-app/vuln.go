package main

import (
	"crypto/sha256"
	"crypto/tls"
	"database/sql"
	"fmt"
	"net/http"
	"os/exec"
)

// Fixed: SQL Injection — using parameterized query
func getUserHandler(w http.ResponseWriter, r *http.Request) {
	db, _ := sql.Open("mysql", "user:pass@/dbname")
	userID := r.URL.Query().Get("id")
	rows, _ := db.Query("SELECT * FROM users WHERE id = ?", userID)
	defer rows.Close()
	fmt.Fprintf(w, "done")
}

// Fixed: Command Injection — passing args directly, no shell
func pingHandler(w http.ResponseWriter, r *http.Request) {
	host := r.URL.Query().Get("host")
	cmd := exec.Command("ping", "-c", "1", host)
	output, _ := cmd.CombinedOutput()
	w.Write(output)
}

// Vulnerability 3: Hardcoded credentials
var (
	dbPassword = "SuperSecret123!"
	apiKey     = "AKIAIOSFODNN7EXAMPLE"
)

// Vulnerability 4: Insecure TLS
func insecureHTTPClient() *http.Client {
	tr := &http.Transport{
		TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
	}
	return &http.Client{Transport: tr}
}

// Fixed: Weak crypto — using SHA256 instead of MD5
func hashPassword(password string) string {
	h := sha256.Sum256([]byte(password))
	return fmt.Sprintf("%x", h)
}
