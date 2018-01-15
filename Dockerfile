FROM ruby:2.3-onbuild

EXPOSE 3001
CMD ["rails", "server", "-b", "0.0.0.0"]

