FROM bosh/init

RUN gem install bosh_cli
RUN mkdir /usr/local/bosh-release
RUN cd /usr/local/bosh-release/ && curl https://bosh.io/d/github.com/cloudfoundry/bosh | tar xf

