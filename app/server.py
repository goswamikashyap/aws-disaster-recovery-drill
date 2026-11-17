import os
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
import psycopg2

DB_HOST = os.environ.get("DB_HOST", "localhost")
DB_PORT = int(os.environ.get("DB_PORT", "5432"))
DB_NAME = os.environ.get("DB_NAME", "ordersdb")
DB_USER = os.environ.get("DB_USER", "postgres")
DB_PASS = os.environ.get("DB_PASS", "ProdSecret2026!")

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/orders":
            try:
                conn = psycopg2.connect(
                    host=DB_HOST, port=DB_PORT, dbname=DB_NAME, user=DB_USER, password=DB_PASS, connect_timeout=2
                )
                cur = conn.cursor()
                cur.execute("SELECT COUNT(*), COALESCE(SUM(amount), 0) FROM customer_orders;")
                count, total = cur.fetchone()
                cur.execute("SELECT order_id, customer_name, amount, created_at FROM customer_orders ORDER BY id DESC LIMIT 5;")
                latest = [{"order_id": r[0], "customer": r[1], "amount": float(r[2]), "created_at": str(r[3])} for r in cur.fetchall()]
                cur.close()
                conn.close()

                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"status": "ONLINE", "db_host": DB_HOST, "total_orders": count, "total_revenue_usd": float(total), "latest_5_orders": latest}, indent=2).encode())
            except Exception as e:
                self.send_response(503)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"status": "OUTAGE_DB_UNREACHABLE", "error": str(e)}, indent=2).encode())
        else:
            self.send_response(404)
            self.end_headers()

print("Starting Orders API on :8090...")
HTTPServer(("0.0.0.0", 8090), Handler).serve_forever()
