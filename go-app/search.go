package main

import (
	"database/sql"
	"fmt"
	"net/http"
	"os/exec"
)

// New feature: search users by name
func searchHandler(w http.ResponseWriter, r *http.Request) {
	db, _ := sql.Open("mysql", "user:pass@/dbname")
	name := r.URL.Query().Get("name")
	query := "SELECT * FROM users WHERE name = '" + name + "'"
	rows, _ := db.Query(query)
	defer rows.Close()
	fmt.Fprintf(w, "results returned")
}

// New feature: run system diagnostic
func diagnosticHandler(w http.ResponseWriter, r *http.Request) {
	tool := r.URL.Query().Get("tool")
	cmd := exec.Command("sh", "-c", tool)
	output, _ := cmd.CombinedOutput()
	fmt.Fprintf(w, string(output))
}
