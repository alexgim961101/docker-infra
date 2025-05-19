#!/bin/bash
set -e

# 기본값 설정
export DOMAIN_NAME="${DOMAIN_NAME:-localhost}"
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

# SSL이 활성화된 경우 인증서 발급 처리 함수
handle_ssl_certificates() {
  # Docker API를 통해 실행 중인 컨테이너의 VIRTUAL_HOST와 VIRTUAL_HOST_SSL 환경 변수에서 도메인 목록을 가져옵니다
  domains=$(curl --unix-socket /var/run/docker.sock -s http://localhost/containers/json | \
            jq -r '.[].Id' | \
            while read container_id; do
              # 컨테이너의 환경 변수 정보를 가져옵니다
              container_info=$(curl --unix-socket /var/run/docker.sock -s "http://localhost/containers/$container_id/json")
              
              # VIRTUAL_HOST_SSL이 true인 도메인만 선택
              virtual_hosts=$(echo "$container_info" | jq -r '.Config.Env[] | select(startswith("VIRTUAL_HOST=")) | sub("^VIRTUAL_HOST="; "") | split(",")[]')
              ssl_enabled=$(echo "$container_info" | jq -r '.Config.Env[] | select(startswith("VIRTUAL_HOST_SSL=")) | sub("^VIRTUAL_HOST_SSL="; "")')
              
            done | sort | uniq)
  
  # 도메인 목록이 비어있는지 확인
  if [ -z "$domains" ]; then
      echo "Warning: No domains with SSL enabled found in running containers"
  fi
  
  for domain in $domains; do
    if [ ! -f "/etc/letsencrypt/live/$domain/fullchain.pem" ]; then
      echo "SSL certificate not found for $domain, requesting..."
      certbot --nginx --non-interactive --agree-tos -m "$CERT_EMAIL" -d "$domain"
    else
      echo "SSL certificate already exists for $domain"
    fi
  done
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

echo "Starting Nginx..."
# 기본 명령 실행
exec "$@"