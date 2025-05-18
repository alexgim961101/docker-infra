#!/bin/bash
set -e

echo "$(date): Starting certificate renewal"

# 인증서 갱신
certbot renew --quiet --nginx --non-interactive

# nginx 재시작 대신 reload
echo "$(date): Reloading Nginx configuration"
nginx -s reload

echo "$(date): Certificate renewal completed"