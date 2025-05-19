# 최신 Nginx LTS 버전
FROM nginx:1.28

# 패키지 설치 시 대화형 모드 비활성화
ENV DEBIAN_FRONTEND=noninteractive

# certbot: SSL 인증서 발급 및 갱신
# python3-certbot-nginx: Nginx와 Certbot을 통합하여 인증서 발급 및 Nginx 설정 자동화를 위한 플러그인
# cron: 자동화된 작업 스케줄링 (SSL 인증서 갱신 용도)
# gettext-base: envsubst 명령어를 포함하며, 템플릿에서 환경변수를 대체하는 데 사용
# docker.io: Docker API에 접근하기 위한 Docker 클라이언트
# curl: HTTP 요청을 보내는 도구 (Docker API 요청에 사용)
# wget: 웹 페이지 다운로드 및 파일 다운로드 도구 (docker-gen 다운로드에 사용)
# jq: JSON 데이터 처리를 위한 도구 (Docker API 응답을 파싱하는 데 사용)
RUN apt-get update && apt-get install -y \
    certbot \
    python3-certbot-nginx \
    cron \
    gettext-base \
    docker.io \
    curl \
    wget \
    jq \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# docker-gen 설치
# docker-gen: Docker 컨테이너 메타데이터를 기반으로 설정 파일을 동적으로 생성하는 도구
RUN wget -qO /tmp/docker-gen.tar.gz https://github.com/nginx-proxy/docker-gen/releases/download/0.14.7/docker-gen-linux-amd64-0.14.7.tar.gz \
    && tar -xzf /tmp/docker-gen.tar.gz -C /usr/local/bin \
    && rm /tmp/docker-gen.tar.gz \
    && chmod +x /usr/local/bin/docker-gen

# 정적 파일 구조화된 디렉토리 생성
RUN mkdir -p /etc/nginx/ssl /etc/nginx/conf.d /etc/nginx/templates \
    /var/lib/letsencrypt/.well-known \
    /var/www/html/sites

# 권한 설정
RUN chmod 700 /etc/nginx/ssl

# 인증서 갱신 스크립트 복사 및 권한 설정
COPY scripts/renew-certs.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/renew-certs.sh

# 템플릿 파일 복사
COPY templates/certbot-cron.template /etc/cron.d/
COPY statics/nginx.conf /etc/nginx/
COPY templates/proxy.conf.tmpl /etc/nginx/templates/

# 시작 스크립트 복사 및 권한 설정
COPY scripts/docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]