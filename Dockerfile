FROM orumin/enju_leaf:1.2.2

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
 && echo "gem 'enju_nii', '~> 0.2.0'" >> Gemfile \
 && echo "gem 'enju_loc', '~> 0.2.0'" >> Gemfile \
 && echo "gem 'enju_oai', '~> 0.2.0'" >> Gemfile \
 && echo "gem 'enju_purchase_request', '~> 0.2.0'" >> Gemfile \
 && echo "gem 'enju_bookmark', '~> 0.2.0'" >> Gemfile

RUN bundle update \
 && rm -rf /enju_leaf/vendor/bundle/ruby/2.4.0/cache

COPY app.patch .
RUN patch -p0 < app.patch
RUN echo 'Manifestation.include(EnjuOai::OaiModel)' >> app/models/user.rb

RUN bundle exec rake enju_purchase_request_engine:install:migrations
RUN bundle exec rake enju_bookmark_engine:install:migrations

ENTRYPOINT ["/sbin/tini", "--"]
