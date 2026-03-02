web: bin/rails server -p ${PORT:-5000} -e $RAILS_ENV
worker: bundle exec rake solid_queue:start
release: bin/rails db:prepare
