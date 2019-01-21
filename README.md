# docker image for enju_leaf

![](https://img.shields.io/docker/automated/orumin/enju_leaf.svg?style#flat-square)
![](https://img.shields.io/microbadger/image-size/orumin/enju_leaf.svg?style#flat-square)
![](https://img.shields.io/microbadger/layers/orumin/enju_leaf.svg?style#flat-square)

## これは何ですか

- 公式では VM が用意されていますがより手軽に試すために作成したイメージです
- なるべく `docker way` な感じに継続的な運用が可能なイメージを目指しました
- Alpine ベースの比較的軽量なイメージです

## はじめに

以降の説明は，次のコマンド

```sh
git clone https://github.com/orumin/enju_leaf.git
cd enju_leaf
```

を行ない，`enju_leaf` ディレクトリをワーキングディレクトリとして作業するものとして説明します。

## インストール（初回起動）

初回の起動は以下の手順で行います。

### イメージの取得

```sh
docker-compose pull
```

### 環境変数の設定とシークレットの設定

```sh
cp .env.production.sample .env.production # ファイル中の UID と GID を変更する際には docker-compose build が必要。後述。
echo SECRET_KEY_BASE=`docker-compose run --rm web bundle exec rake secret` >> .env.production
```

### デフォルトのカバー画像・書誌形態画像，マイグレーションファイルの保存

```sh
id=`docker create orumin/enju_leaf:1.2.2`
docker cp $id:/enju_leaf/db/migrate .
docker cp $id:/enju_leaf/private/system .
docker rm -v $id

sudo chown 991:991 -R ./system ./migrate # .env.production の UID と GID の値に合わせる
```

### データベースの初期設定

```sh
export DB_USER=enju_leaf DB_NAME=enju_leaf_production DB_PASS=admin # .env.production に合わせる
docker-compose up -d db
  && sleep 10 \
  && docker-compose exec -u postgres db sh -c "echo create user ${DB_USER} with password \'${DB_PASS}\' createdb\; | psql -f -" \
  && docker-compose exec -u postgres db createdb -U ${DB_USER} ${DB_NAME}
docker-compose run --rm web bundle exec rake db:migrate
docker-compose run --rm web bundle exec rake enju_leaf:setup
docker-compose run --rm web bundle exec rake enju_circulation:setup
docker-compose run --rm web bundle exec rake enju_subject:setup
docker-compose run --rm web bundle exec rake db:seed
```

### アセットファイルのプリコンパイル

```sh
mkdir -p assets
sudo chown 991:991 -R ./assets # .env.production の UID と GID の値に合わせる
docker-compose run --rm web bundle exec rake assets:precompile
```

### データベース更新とアセットのロード

```sh
docker-compose run --rm web bundle exec rake enju_leaf:upgrade
docker-compose run --rm web bundle exec rake enju_leaf:load_asset_files
```

### 起動

```sh
docker-compose up -d
sleep 30 && docker-compose exec web bundle exec rake environment sunspot:reindex
```

### ログイン

初期設定ではユーザー名 `enjuadmin` パスワード `adminpassword` でログインできます。
以降のシステム設定や OPAC 運用方法などは [公式マニュアル](https://next-l.github.io/manual/1.2/) をご覧ください。

## 毎回の起動方法と終了方法

### 起動

```sh
docker-compose up -d
sleep 30 && docker-compose exec web bundle exec rake environment sunspot:reindex
```

### 終了

```sh
docker-compose down
```

## アップデート（1.2.2 から 1.3.1 で動作確認）

初回起動時に作成した `./migrate` ディレクトリとその中身のマイグレーションファイルが同じディレクトリに配置されていること，
既に一度システムが起動済であり PostgreSQL のロールやデータベース・テーブルなどが設定されていること，
そのデータベースが `./postgresql` に存在していることが前提です。

### Dockerfile の更新とコンテナの更新（ビルド）

```sh
git pull
docker-compose pull # コンテナのビルドの際には sudo docker-compose build --pull
```

### マイグレーションの実行

```sh
# 1.2.1 以下から 1.2.2 以上へのアップデートの時はおそらく
# docker-compose run --rm web bundle exec rake railties:install:migrations
# でマイグレーションファイルを追加する必要がある。
# ほかにも migrate に先立って必要な作業が随時発生する可能性があるため，
# 公式ドキュメント https://github.com/next-l/enju_leaf/wiki/Update を参考の上で実施すること
docker-compose run --rm web bundle exec rake db:migrate
docker-compose run --rm web bundle exec rake enju_leaf:upgrade
```

### アセットのプリコンパイル

```sh
docker-compose run --rm web bundle exec rake assets:precompile
```

### システムを停止と再起動

```sh
docker-compose stop && docker-compose up -d
sleep 30 && docker-compose exec web bundle exec rake sunspot:reindex
```

## バックアップと他マシンでの起動

### バックアップ

この作業ディレクトリをまるごとバックアップしてください。

### 他マシンでの起動

まずバックアップしたディレクトリを移動し，その中で新しいマシンでの作業を行います。

以下のように権限を修正してください。

```sh
chown 70:0 -R ./postgres
sudo chown 991:991 -R ./system ./assets ./migrate # .env.production の UID と GID の値に合わせる
```

最後に起動を行います。

```sh
docker-compose up -d
sleep 30 && docker-compose exec web bundle exec rake environment sunspot:reindex
```

## .env.production について

UID と GID ならびに DB_USER の変更はコンテナのビルドを伴う必要があります。
具体的には以下のようにビルドを行った後に .env.production に変更を反映させてください。

```sh
docker-compose build \
    --build-arg UID=1000 \
    --build-arg GID=1000 \
    --build-arg DB_USER=enju
```

また，DB_USER, DB_NAME, DB_PASS の変更の際にはデータベースの再設定が必要です。

```sh
# OLD_DB_USER は DB_USER を変更する前の値
# OLD_DB_NAME は DB_NAME を変更する前の値
export OLD_DB_USER=enju_leaf DB_USER=enju \
       OLD_DB_NAME=enju_leaf_production DB_NAME=production \
       DB_PASS=root
docker-compose up -d db \
  && sleep 10 \
  && docker-compose exec -u postgres db sh -c "pg_dump ${OLD_DB_NAME} > enju_dump.sql" \
  && docker-compose exec -u postgres db dropdb ${OLD_DB_NAME} \
  && docker-compose exec -u postgres db sh -c "echo drop user ${OLD_DB_USER} | psql -f -" \
  && docker-compose exec -u postgres db sh -c "echo create user ${DB_USER} with password \'${DB_PASS}\' createdb\; | psql -f -" \
  && docker-compose exec -u postgres db createdb -U ${DB_USER} ${DB_NAME}
  && docker-compose exec -u postgres db psql ${DB_NAME} -f enju_dump.sql
```

おそらく，運用上では，.env.production で設定した UID, GID と同じ値を持つユーザーを作成し，
そのユーザーのホームディレクトリ以下で運用するといちいち chown などで権限を変更する手間が省けると思われます。

## 同梱のシェルスクリプトについて

`install.sh`, `update.sh`, `start.sh`, `stop.sh` は本 README で解説したそれぞれの手順をシェルスクリプトにしたものです。
とくにエラーチェックなどは一切しない簡易なものなので参考程度にしてください。
また， `install.sh` は `sudo` をつけて実行することが好ましいと思われます。
