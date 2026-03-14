FROM nginx:alpine

# Remove default server block
RUN rm /etc/nginx/conf.d/default.conf

# Copy Odoo reverse-proxy config
COPY ./nginx/nginx.conf /etc/nginx/conf.d/odoo.conf

# Railway injects PORT at runtime; replace listen directive accordingly
CMD sh -c "sed -i \"s/listen 80/listen ${PORT:-80}/\" /etc/nginx/conf.d/odoo.conf && nginx -g 'daemon off;'"
