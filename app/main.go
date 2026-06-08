package main

import (
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"

	_ "github.com/microsoft/go-mssqldb"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8000"
	}

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "Hello from Go on Azure 👋")
	})

	http.HandleFunc("/db", dbHandler)

	log.Printf("listening on :%s", port)
	log.Fatal(http.ListenAndServe(":"+port, nil))
}

func dbHandler(w http.ResponseWriter, r *http.Request) {
	connStr := os.Getenv("SQL_CONNECTION_STRING")
	if connStr == "" {
		http.Error(w, "brak SQL_CONNECTION_STRING w środowisku", http.StatusInternalServerError)
		return
	}

	db, err := sql.Open("sqlserver", connStr)
	if err != nil {
		http.Error(w, "open: "+err.Error(), http.StatusInternalServerError)
		return
	}
	defer db.Close()

	var serverTime, version string
	err = db.QueryRow("SELECT CONVERT(varchar, SYSDATETIME(), 120), @@VERSION").Scan(&serverTime, &version)
	if err != nil {
		http.Error(w, "query: "+err.Error(), http.StatusInternalServerError)
		return
	}

	fmt.Fprintf(w, "Połączono z Azure SQL \u2705\nCzas serwera: %s\n\n%s\n", serverTime, version)
}
