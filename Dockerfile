# OpenSEO standalone edition, packaged as one Railway service.
# Upstream runs five Compose services (storage, runtime, init, crawl-gateway,
# web). Railway can't share volumes or network namespaces between services, so
# this image runs runtime, init, crawl gateway and Nginx in one container, and
# keeps celld's state in an S3 bucket (a Railway Bucket in the template).
FROM ghcr.io/every-app/open-seo-standalone:v0.1.29@sha256:5817dd88b16be5250eed170369c94b882f8ab40fb645f75dbd0da7c047207702

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends nginx \
 && rm -rf /var/lib/apt/lists/* /etc/nginx/sites-enabled /etc/nginx/conf.d/* \
 && mkdir -p /opt/railway

# Derive our copies from upstream's scripts so their logic stays upstream's.
# Each edit is checked, so a build fails loudly if an update changes the lines.
RUN set -eux; \
    s=/opt/standalone; r=/opt/railway; \
    sed 's#http://crawl-gateway:8090#http://127.0.0.1:8090#' $s/configure.mjs > $r/configure.mjs; \
    grep -q '"http://127.0.0.1:8090"' $r/configure.mjs; \
    sed -e 's#node /opt/standalone/configure.mjs#node /opt/railway/configure.mjs#' \
        -e 's#^install -m 0644 /opt/standalone/nginx.conf /web-config/default.conf$#: nginx config is written by start.sh#' $s/init.sh > $r/init.sh; \
    grep -q 'node /opt/railway/configure.mjs' $r/init.sh; \
    ! grep -q 'web-config' $r/init.sh; \
    sed 's#--listen 0.0.0.0:8080#--listen 127.0.0.1:8080#' $s/run.sh > $r/run.sh; \
    grep -q -- '--listen 127.0.0.1:8080 --internal-listen 127.0.0.1:8081' $r/run.sh; \
    sed -e 's#^  listen 80;$#  listen __PORT__;\n  listen [::]:__PORT__;#' \
        -e 's#proxy_pass http://runtime:8080;#proxy_pass http://127.0.0.1:8080;#' $s/nginx.conf > $r/site.conf.in; \
    grep -q 'listen __PORT__;' $r/site.conf.in; \
    grep -q 'proxy_pass http://127.0.0.1:8080;' $r/site.conf.in; \
    rm -r /config /data; \
    ln -s /var/lib/openseo/config /config; \
    ln -s /var/lib/openseo/data /data

COPY entrypoint.sh start.sh nginx.conf /opt/railway/
RUN chmod 0755 /opt/railway/entrypoint.sh /opt/railway/start.sh

ENV CELLD_WATCH=/var/lib/openseo/data
ENTRYPOINT ["/opt/railway/entrypoint.sh"]
