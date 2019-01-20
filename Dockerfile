FROM node:8.15-alpine as node
FROM ruby:2.6-alpine3.8

LABEL maintainer="https://github.com/orumin/enju_leaf"

ARG UID=991
ARG GID=991
ARG DB_USER=enju_leaf

ENV DB_USER ${DB_USER:-enju_leaf}
ENV DB_PASS admin
ENV DB_NAME enju_leaf_production
ENV DB_HOST db
ENV RAILS_SERVE_STATIC_FILES true
ENV REDIS_URL redis://redis/enju_leaf
ENV SOLR_URL  http://solr:8983/solr/default
ENV RAILS_ENV production

EXPOSE 3000

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node /usr/local/bin/npm /usr/local/bin/npm
COPY --from=node /opt/yarn-* /opt/yarn

RUN apk add --no-cache --virtual .build-deps \
    build-base \
    icu-dev \
    libressl \
    libxslt-dev \
    postgresql-dev \
    zlib-dev \
 && apk add --no-cache \
    busybox-suid \
    bash \
    file \
    git \
    openjdk8-jre-base \
    icu-libs \
    imagemagick \
    libpq \
    libxslt \
    redis \
    tini \
    tzdata \
    unzip \
 && update-ca-certificates \
 && ln -s /opt/yarn/bin/yarn /usr/local/bin/yarn \
 && ln -s /opt/yarn/bin/yarnpkg /usr/local/bin/yarnpkg \
 && gem install bundler -v=1.17.2 \
 && gem install rails -v=5.1.6 \
 && gem install foreman whenever \
 && rails _5.1.6_ new enju_leaf -d postgresql --skip-bundle --skip-turbolinks \
    -m https://gist.github.com/nabeta/6c56f0edf5cc1c80d9c655c2660a9c59.txt \
 && cd enju_leaf \
 && bundle config --local path vendor/bundle \
 && bundle config --local without test:development:doc \
 && bundle install -j$(getconf _NPROCESSORS_ONLN) \
 && rm -rf /enju_leaf/vendor/bundle/ruby/2.6.0/cache \
 && rm -rf /root/.bundle/cache \
 && sed -i -e "s/\(skip_after_action :verify_authorized\)/\1, raise: false/" \
    $(find . -type f -name '*.rb' -exec grep -H 'verify_authorized' {} \; \
      | grep skip_after_action \
      | awk -F: '{print $1}') \
 && sed -i -e "s/\(skip_before_action :store_current_location\)/\1, raise: false/" \
    $(find . -type f -name '*.rb' -exec grep -H 'store_current_location' {} \; \
      | grep skip_before_action \
      | awk -F: '{print $1}') \
 && apk del --purge .build-deps

WORKDIR /enju_leaf

RUN addgroup -g ${GID} ${DB_USER} && adduser -h /enju_leaf -s /bin/sh -D -G ${DB_USER} -u ${UID} ${DB_USER} \
 && chown -R ${DB_USER}:${DB_USER} /enju_leaf

RUN apk add --no-cache postgresql openrc \
 && mkdir -p /run/openrc /run/postgresql \
 && touch /run/openrc/softlevel \
 && /etc/init.d/postgresql setup \
 && chown postgres:postgres /run/postgresql && chown postgres:postgres /var/lib/postgresql \
 && su postgres -c "nohup sh -c 'pg_ctl start -- --pgdata=/var/lib/postgresql/10/data'" \
 && sleep 10 \
 && su postgres -c "echo create user ${DB_USER} with password \'${DB_PASS}\' createdb\; | psql -f -" \
 && su postgres -c "createdb -U ${DB_USER} ${DB_NAME}" \
 && su enju_leaf -c 'SECRET_KEY_BASE=placeholder bundle exec rails g enju_leaf:setup' \
 && su enju_leaf -c 'SECRET_KEY_BASE=placeholder bundle exec rails g enju_leaf:quick_install' \
 && apk del --purge postgresql openrc \
 && rm -rf log tmp \
 && rm -rf /var/lib/postgresql \
 && cd /run \
 && rm -rf openrc postgresql

USER ${DB_USER}

RUN whenever --update-crontab

COPY resque.rb config/initializers/
COPY database.yml resque.yml sunspot.yml config/

ENTRYPOINT ["/sbin/tini", "--"]
