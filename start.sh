#!/bin/sh

docker-compose up -d
sleep 30 && docker-compose exec solr bundle exec rake environment sunspot:reindex
