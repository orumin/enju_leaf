#!/bin/sh

docker-compose up -d
sleep 30 && docker-compose exec web bundle exec rake environment sunspot:reindex
