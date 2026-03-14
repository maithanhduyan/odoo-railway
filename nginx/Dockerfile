FROM nginx:alpine

# Remove default server block
RUN rm /etc/nginx/conf.d/default.conf

# Copy config as template
COPY ./nginx/nginx.conf /etc/nginx/templates/odoo.conf.template

# Copy entrypoint script
COPY ./nginx/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
