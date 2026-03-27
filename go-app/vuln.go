package main

import (
	"crypto/md5"
	"crypto/tls"
	"database/sql"
	"fmt"
	"net/http"
	"os/exec"
)

// Vulnerability 1: SQL Injection
func getUserHandler(w http.ResponseWriter, r *http.Request) {
	db, _ := sql.Open("mysql", "user:pass@/dbname")
	userID := r.URL.Query().Get("id")
	query := "SELECT * FROM users WHERE id = " + userID
	rows, _ := db.Query(query)
	defer rows.Close()
	fmt.Fprintf(w, "done")
}

// Vulnerability 2: Command Injection
func pingHandler(w http.ResponseWriter, r *http.Request) {
	host := r.URL.Query().Get("host")
	cmd := exec.Command("sh", "-c", "ping -c 1 "+host)
	output, _ := cmd.CombinedOutput()
	fmt.Fprintf(w, string(output))
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

// Vulnerability 5: Weak crypto (MD5)
func hashPassword(password string) string {
	h := md5.Sum([]byte(password))
	return fmt.Sprintf("%x", h)
}
