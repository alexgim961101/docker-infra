#!/bin/bash
set -e

# 기본값 설정
export DOMAIN_NAME="${DOMAIN_NAME:-localhost}"
export SSL_ENABLED="${SSL_ENABLED:-false}"
export CERT_RENEWAL_DAYS="${CERT_RENEWAL_DAYS:-1,5}"
export CERT_RENEWAL_HOUR="${CERT_RENEWAL_HOUR:-0}"
export CERT_RENEWAL_MIN="${CERT_RENEWAL_MIN:-45}"
export CERT_EMAIL="${CERT_EMAIL:-admin@example.com}"
export PROXY_TIMEOUT="${PROXY_TIMEOUT:-60s}"
export DEFAULT_HTTP_VERSION="${DEFAULT_HTTP_VERSION:-1.0}"
export DEFAULT_WEBSOCKET="${DEFAULT_WEBSOCKET:-false}"

# 인증서 갱신 크론 작업 생성
envsubst < /etc/cron.d/certbot-cron.template > /etc/cron.d/certbot-cron
chmod 0644 /etc/cron.d/certbot-cron

# Nginx 기본 설정 파일 생성
envsubst < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# SSL이 활성화된 경우 인증서 발급 처리 함수
handle_ssl_certificates() {
  if [ "$SSL_ENABLED" = "true" ]; then
    # Docker API를 통해 VIRTUAL_HOST 환경 변수를 가진 컨테이너 찾기
    domains=$(curl --unix-socket /var/run/docker.sock -s http://localhost/containers/json | \
              jq -r '.[] | select(.Env | contains("VIRTUAL_HOST")) | .Env[] | select(startswith("VIRTUAL_HOST=")) | split("=")[1] | split(",")[]' | sort | uniq)
    
    for domain in $domains; do
      if [ ! -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]; then
        echo "SSL certificate not found for $domain, requesting..."
        certbot --nginx --non-interactive --agree-tos -m "$CERT_EMAIL" -d "$domain"
      else
        echo "SSL certificate already exists for $domain"
      fi
    done
  fi
}

# docker-gen을 통해 설정 파일 생성 및 갱신 함수
setup_docker_gen() {
  # 초기 설정 파일 생성
  docker-gen -notify-sighup nginx -watch -wait 5s:30s /etc/nginx/templates/proxy.conf.tmpl /etc/nginx/conf.d/default.conf &
  
  # 상태 로그
  echo "docker-gen started for dynamic config generation"
}

# cron 서비스 시작
service cron start

# SSL 인증서 처리
handle_ssl_certificates

# docker-gen 설정 및 시작
setup_docker_gen

# nginx 설정 테스트
echo "Testing Nginx configuration..."
nginx -t

# 기본 명령 실행
exec "$@"