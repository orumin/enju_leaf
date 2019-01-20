#!/bin/sh

docker-compose up -d
docker-compose exec bundle exec rake sunspot:reindex
