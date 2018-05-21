FROM ruby:2.4-slim-stretch

MAINTAINER William Budington "bill@eff.org"

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    apt-transport-https \
    ca-certificates \
    gnupg \
    default-libmysqlclient-dev \
    libpq-dev \
    git \
    qt5-default \
    xvfb \
    lsof \
    imagemagick \
    cron && \
  curl -sSL https://dl.google.com/linux/linux_signing_key.pub | apt-key add - && \
  echo "deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
  apt-get update && \
  apt-get install -y google-chrome-stable --no-install-recommends && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

# Datasources should be a persistent volume
VOLUME /datasources

RUN mkdir /opt/phantomdc
WORKDIR /opt/phantomdc
ADD Gemfile Gemfile.lock ./
ADD ./cwc/ ./cwc

RUN bundle install

ADD app ./app
ADD lib ./lib
ADD config ./config
ADD db ./db
ADD public ./public
ADD spec ./spec
ADD tasks ./tasks
ADD Procfile README.md Rakefile config.ru phantom-dc ./

RUN cp config/database.rb.example config/database.rb
RUN cp config/phantom-dc_config.rb.example config/phantom-dc_config.rb

ENV RACK_ENV production

ADD ./docker/app/entrypoint.sh ./
CMD ["thin", "start", "--port", "3001", "--threaded"]
ENTRYPOINT ["/opt/phantomdc/entrypoint.sh"]
