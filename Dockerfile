FROM debian

MAINTAINER William Budington "bill@eff.org"

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
    openssh-client \
    curl \
    imagemagick \
    libmysql++-dev \
    libpq-dev \
    git \
    libqt5webkit5-dev \
    qt5-default \
    xvfb \
    lsof \
    sudo \
    bzip2 \
    ca-certificates && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

# Create a symlink to what will be the phantomjs exec path
RUN ln -s /home/phantomdc/phantomjs-1.9.8-linux-x86_64/bin/phantomjs /bin/phantomjs

# Create a new user, phantomdc
RUN export uid=1000 gid=1000 && \
    mkdir -p /home/phantomdc && \
    echo "phantomdc:x:${uid}:${gid}:PhantomDC,,,:/home/phantomdc:/bin/bash" >> /etc/passwd && \
    echo "phantomdc:x:${uid}:" >> /etc/group && \
    echo "phantomdc ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/phantomdc && \
    chmod 0440 /etc/sudoers.d/phantomdc && \
    chown ${uid}:${gid} -R /home/phantomdc
USER phantomdc
ENV HOME /home/phantomdc/

# Get the rvm signing key in a secure way
RUN mkdir /tmp/gpg && \
  chmod 700 /tmp/gpg && \
  gpg --homedir /tmp/gpg --keyserver keys.gnupg.net --recv D39DC0E3 && \
  gpg --homedir /tmp/gpg --export 409B6B1796C275462A1703113804BB82D39DC0E3 | gpg --import - && \
  rm -rf /tmp/gpg

WORKDIR /home/phantomdc

# Set up phantomjs
RUN curl -Lo phantomjs.tar.bz2 https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-1.9.8-linux-x86_64.tar.bz2 && \
  tar -jxvf phantomjs.tar.bz2 > /dev/null && \
  rm phantomjs.tar.bz2

RUN curl -O https://raw.githubusercontent.com/wayneeseguin/rvm/master/binscripts/rvm-installer
RUN curl -O https://raw.githubusercontent.com/wayneeseguin/rvm/master/binscripts/rvm-installer.asc
RUN gpg --verify rvm-installer.asc

RUN bash rvm-installer stable
RUN bash -l -c 'rvm install ruby-2.2.0'

RUN mkdir /home/phantomdc/phantom-of-the-capitol
WORKDIR /home/phantomdc/phantom-of-the-capitol

ADD Gemfile Gemfile.lock .ruby-gemset .ruby-version ./
RUN bash -l -c 'bundle install'

RUN mkdir app config db public spec tasks
ADD app ./app/
ADD config ./config/
ADD db ./db/
ADD public ./public/
ADD spec ./spec/
ADD tasks ./tasks/
ADD Procfile README.md Rakefile config.ru ./

# Datasources should be a persistent volume, owned by phantomdc
# All the above added files & directories should also be owned by phantomdc
USER root
RUN mkdir /datasources
RUN chown -R phantomdc:phantomdc /datasources .
VOLUME /datasources
USER phantomdc

RUN cp config/database.rb.example config/database.rb
RUN cp config/phantom-dc_config.rb.example config/phantom-dc_config.rb

RUN sed -i 's/AWS/Local' config/phantom-dc_config.rb
RUN DEBUG_KEY=`head -c 30 /dev/urandom | base64 | sed -e 's/+/-/g' -e 's/\//./g'` && \
  sed -i "s/DEBUG_KEY = \"\"/DEBUG_KEY = \"$DEBUG_KEY\"/g" config/phantom-dc_config.rb

ADD ./docker/phantomdc/entrypoint.sh /home/phantomdc/
CMD ["bash", "-l", "-c", "thin start --port 3001 --threaded"]
ENTRYPOINT ["/home/phantomdc/entrypoint.sh"]
