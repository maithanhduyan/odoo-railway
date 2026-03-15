FROM edoburu/pgbouncer:latest

COPY --chmod=666 ./pgbouncer/pgbouncer.ini /etc/pgbouncer/pgbouncer.ini
COPY --chmod=666 ./pgbouncer/userlist.txt /etc/pgbouncer/userlist.txt
COPY --chmod=755 ./pgbouncer/entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
