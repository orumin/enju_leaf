#!/bin/sh

docker-compose run --rm web bundle exec rake db:migrate
docker-compose run --rm web bundle exec rake assets:precompile
docker-compose run --rm web bundle exec rake enju_leaf:upgrade
docker-compose run --rm web bundle exec rake enju_leaf:load_asset_files
