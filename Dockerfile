FROM ruby:2.3.0-onbuild

EXPOSE 3001
CMD ["rails", "server", "-b", "0.0.0.0", "-p", "3001"]

