FROM dpage/pgadmin4:latest

# Pre-configure server list so Postgres appears automatically on first login
COPY --chmod=644 ./pgadmin/servers.json /pgadmin4/servers.json
