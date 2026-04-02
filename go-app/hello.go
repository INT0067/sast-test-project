package main

  import (
        "database/sql"
        "fmt"
        "net/http"
  )


  func paymentHandler(w http.ResponseWriter, r *http.Request) {
        db, _ := sql.Open("mysql", "user:pass@/dbname")
        amount := r.URL.Query().Get("amount")    // user input from URL
        userID := r.URL.Query().Get("user_id")   // user input from URL

        // ERROR: user input directly concatenated into SQL query
        // attacker can send: amount=0&user_id=1 OR 1=1
        // this would modify ALL users' wallets
        query := "UPDATE wallets SET balance = balance - " + amount + " WHERE user_id = " + userID
        db.Exec(query)

        fmt.Fprintf(w, "Payment processed")
  }
