import sqlite3

conn = sqlite3.connect("companies.db")
cur = conn.cursor()
cur.execute("SELECT id, name, industry FROM companies;")
rows = cur.fetchall()
print(rows)
conn.close()