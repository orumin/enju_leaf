#!/bin/sh

docker-compose pull

cp .env.production.sample .env.production

echo SECRET_KEY_BASE=`docker-compose run --rm web bundle exec rake secret` >> .env.production

id=`docker create orumin/enju_leaf:1.3.2-fullmod`
sudo docker cp $id:/enju_leaf/db/migrate .
docker cp $id:/enju_leaf/private/system .
docker rm -v $id

sudo chown 991:991 -R ./system ./migrate

export DB_USER=enju_leaf DB_NAME=enju_leaf_production DB_PASS=admin
sleep 10 \
  && docker-compose exec -u postgres db sh -c "echo create user ${DB_USER} with password \'${DB_PASS}\' createdb\; | psql -f -" \
  && docker-compose exec -u postgres db createdb -U ${DB_USER} ${DB_NAME}
docker-compose run --rm web bundle exec rake db:migrate
docker-compose run --rm web bundle exec rake enju_leaf:setup
docker-compose run --rm web bundle exec rake enju_circulation:setup
docker-compose run --rm web bundle exec rake enju_subject:setup
docker-compose run --rm web bundle exec rake db:seed

mkdir -p ./assets
sudo chown 991:991 assets
docker-compose run --rm web bundle exec rake assets:precompile

docker-compose run --rm web bundle exec rake enju_leaf:upgrade

docker-compose run --rm web bundle exec rake enju_leaf:load_asset_files

docker-compose up -d
sleep 30 && docker-compose exec solr bundle exec rake environment sunspot:reindex
