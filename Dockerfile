FROM ubuntu
RUN apt-get update
RUN apt-get -y install curl imagemagick libmysql++-dev libpq-dev git libqt4-dev xvfb lsof

# Create a new user and switch to that user
RUN export uid=1000 gid=1000 && \
    mkdir -p /home/phantomdc && \
    echo "phantomdc:x:${uid}:${gid}:PhantomDC,,,:/home/phantomdc:/bin/bash" >> /etc/passwd && \
    echo "phantomdc:x:${uid}:" >> /etc/group && \
    echo "phantomdc ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/phantomdc && \
    chmod 0440 /etc/sudoers.d/phantomdc && \
    chown ${uid}:${gid} -R /home/phantomdc
USER phantomdc
ENV HOME /home/phantomdc/

# Get the rvm signing key
RUN mkdir /tmp/gpg
WORKDIR /tmp/gpg
RUN chmod 700 /tmp/gpg
RUN gpg --homedir /tmp/gpg --keyserver keys.gnupg.net --recv D39DC0E3
RUN gpg --homedir /tmp/gpg --export 409B6B1796C275462A1703113804BB82D39DC0E3 | gpg --import -
RUN rm -rf /tmp/gpg

WORKDIR /home/phantomdc

# Set up phantomjs
RUN curl -Lo phantomjs.tar.bz2 https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-1.9.8-linux-x86_64.tar.bz2
RUN tar -jxvf phantomjs.tar.bz2 > /dev/null
RUN rm phantomjs.tar.bz2
ENV PATH $PATH:/home/phantomdc/phantomjs-1.9.8-linux-x86_64/bin

RUN curl -O https://raw.githubusercontent.com/wayneeseguin/rvm/master/binscripts/rvm-installer
RUN curl -O https://raw.githubusercontent.com/wayneeseguin/rvm/master/binscripts/rvm-installer.asc
RUN gpg --verify rvm-installer.asc

RUN bash rvm-installer stable
RUN bash -l -c 'rvm install ruby-2.2.0'

RUN mkdir /home/phantomdc/phantom-of-the-capitol
WORKDIR /home/phantomdc/phantom-of-the-capitol

ADD Gemfile Gemfile.lock .ruby-gemset .ruby-version ./
RUN bash -l -c 'gem install json -v 1.8.2'
RUN bash -l -c 'gem install nokogiri -v 1.6.6.2'
RUN bash -l -c 'bundle install'

RUN mkdir app config db public spec tasks
ADD app ./app/
ADD config ./config/
ADD db ./db/
ADD public ./public/
ADD spec ./spec/
ADD tasks ./tasks/
ADD Procfile README.md Rakefile config.ru ./

USER root
RUN chown -R phantomdc:phantomdc .
USER phantomdc

RUN cp config/database-example.rb config/database.rb
RUN cp config/phantom-dc_config.rb.example config/phantom-dc_config.rb

ADD ./docker/phantomdc/entrypoint.sh /home/phantomdc/
CMD ["bash", "-l", "-c", "thin start --port 3001 --threaded"]
ENTRYPOINT ["/home/phantomdc/entrypoint.sh"]
