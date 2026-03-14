FROM odoo:19.0

USER root
RUN pip3 install --no-cache-dir boto3

# Copy custom addons (s3_attachment)
COPY ./odoo/19.0/addons /mnt/extra-addons

COPY --chmod=755 ./odoo/19.0/entrypoint.sh /entrypoint.sh

