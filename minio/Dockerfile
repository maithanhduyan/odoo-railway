FROM minio/minio:latest

COPY ./minio/entrypoint.sh /custom-entrypoint.sh
RUN chmod +x /custom-entrypoint.sh

ENTRYPOINT []
CMD ["/bin/sh", "/custom-entrypoint.sh"]
