package main

import (
	"fmt"
	"net"
	"net/http"
	"strings"
)

func main() {
	http.HandleFunc("/headers", headers)
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		ip := getOriginPublicIP(r)
		reversedIP := reverseIP(ip)
		fmt.Fprintf(w, "Source IP Address: %s", reversedIP)
	})

	fmt.Println("Server running on port 8090...")
	http.ListenAndServe(":8090", nil)
}

func getOriginPublicIP(r *http.Request) string {
	ip := r.Header.Get("X-Forwarded-For")
	if ip == "" {
		ip = r.Header.Get("X-Real-IP")
	}
	if ip == "" {
		ip, _, _ = net.SplitHostPort(r.RemoteAddr)
	}
	return ip
}

func headers(w http.ResponseWriter, req *http.Request) {

	for name, headers := range req.Header {
		for _, h := range headers {
			fmt.Fprintf(w, "%v: %v\n", name, h)
		}
	}
}

func reverseIP(ip string) string {
	segments := strings.Split(ip, ".")
	reversedSegments := make([]string, len(segments))
	for i, j := 0, len(segments)-1; i < len(segments); i, j = i+1, j-1 {
		reversedSegments[i] = segments[j]
	}
	return strings.Join(reversedSegments, ".")
}
