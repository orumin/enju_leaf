FROM orumin/enju_leaf:1.3.3

LABEL maintainer="https://github.com/orumin/enju_leaf_docker"

ENV DB_USER enju_leaf
ENV DB_PASS admin
ENV DB_NAME enju_leaf_production
ENV DB_HOST db
ENV RAILS_SERVE_STATIC_FILES true
ENV REDIS_URL redis://redis/enju_leaf
ENV SOLR_URL  http://solr:8983/solr/default
ENV RAILS_ENV production

EXPOSE 3000

RUN echo "" >> Gemfile \
 && echo "gem 'enju_nii', '~> 0.3.0'" >> Gemfile \
 && echo "gem 'enju_loc', '~> 0.3.0'" >> Gemfile \
 && echo "gem 'enju_oai', '~> 0.3.0'" >> Gemfile \
 && echo "gem 'enju_purchase_request', '~> 0.3.1'" >> Gemfile \
 && echo "gem 'enju_bookmark', '~> 0.3.1'" >> Gemfile

RUN bundle update \
 && rm -rf /enju_leaf/vendor/bundle/ruby/2.6.0/cache

COPY modules.patch .
RUN patch -p1 < modules.patch

RUN bundle exec rake enju_purchase_request_engine:install:migrations
RUN bundle exec rake enju_bookmark_engine:install:migrations

ENTRYPOINT ["/sbin/tini", "--"]
