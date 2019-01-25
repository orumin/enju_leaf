FROM node:8.15-alpine as node
FROM ruby:2.4-alpine3.6

LABEL maintainer="https://github.com/orumin/enju_leaf"

ARG UID=991
ARG GID=991
ARG DB_USER=enju_leaf

ENV DB_USER ${DB_USER:-enju_leaf}
ENV DB_PASS admin
ENV DB_NAME enju_leaf_production
ENV DB_HOST db
ENV RAILS_SERVE_STATIC_FILES true
ENV REDIS_URL redis://127.0.0.1/enju_leaf
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
 && gem install rails -v=4.2.10 \
 && gem install foreman whenever \
 && rails _4.2.10_ new enju_leaf -d postgresql --skip-bundle \
    -m https://gist.github.com/nabeta/8024918f41242a16719796c962ed2af1.txt \
 && cd enju_leaf \
 && bundle config --local path vendor/bundle \
 && bundle config --local without test:development:doc \
 && bundle install -j$(getconf _NPROCESSORS_ONLN) \
 && rm -rf /enju_leaf/vendor/bundle/ruby/2.4.0/cache \
 && rm -rf /root/.bundle/cache \
 && apk del --purge .build-deps

WORKDIR /enju_leaf

RUN addgroup -g ${GID} ${DB_USER} && adduser -h /enju_leaf -s /bin/sh -D -G ${DB_USER} -u ${UID} ${DB_USER} \
 && chown -R ${DB_USER}:${DB_USER} /enju_leaf

RUN apk add --no-cache postgresql openrc \
 && mkdir -p /run/openrc /run/postgresql \
 && touch /run/openrc/softlevel \
 && /etc/init.d/postgresql setup \
 && chown postgres:postgres /run/postgresql && chown postgres:postgres /var/lib/postgresql \
 && su postgres -c "nohup sh -c 'pg_ctl start -- --pgdata=/var/lib/postgresql/9.6/data'" \
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

RUN echo 'redis: redis-server' > Procfile \
 && echo 'solr: bundle exec rake sunspot:solr:run' >> Procfile \
 && echo 'resque: bundle exec rake resque:work QUEUE=enju_leaf,mailers TEAM_CHILD=1' >> Procfile \
 && echo 'web: bundle exec rails s -b 0.0.0.0 -p 3000' >> Procfile

COPY database.yml config/

ENTRYPOINT ["/sbin/tini", "--"]
