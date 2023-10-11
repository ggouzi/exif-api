FROM ruby:2.4.3
MAINTAINER gouzi.gaetan@gmail.com

RUN apt-get update && \
    apt-get install -y net-tools libimage-exiftool-perl

# Install gems
ENV APP_HOME /app
ENV HOME /root
RUN mkdir $APP_HOME
WORKDIR $APP_HOME
COPY Gemfile* $APP_HOME/
RUN gem install bundler && bundle install --jobs 20 --retry 5

# Upload source
COPY . $APP_HOME

# Start server
EXPOSE 3000
CMD ["bundle", "exec", "rackup", "-o", "0.0.0.0"]
