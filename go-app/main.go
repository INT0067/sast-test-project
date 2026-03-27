package main

import (
	"fmt"
	"net/http"
)

func healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	fmt.Fprintf(w, `{"status": "ok"}`)
}

func main() {
	http.HandleFunc("/health", healthHandler)
	fmt.Println("Server starting on :8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		fmt.Printf("Server failed: %v\n", err)
	}
}
