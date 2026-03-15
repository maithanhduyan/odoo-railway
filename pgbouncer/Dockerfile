FROM edoburu/pgbouncer:1.24.0

COPY --chmod=644 pgbouncer.ini /etc/pgbouncer/pgbouncer.ini
COPY --chmod=644 userlist.txt /etc/pgbouncer/userlist.txt
COPY --chmod=755 entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
