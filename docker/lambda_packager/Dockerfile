FROM node:12

# COPY /app /app
RUN apt-get update -y
RUN apt-get install zip -y
RUN mkdir /app
WORKDIR /app

CMD  npm install && npm run predeploy

# Run docker with current files
# docker build -t lambda_packager .
# docker run --rm \
#   --name lambda_packager  \
#   --mount type=bind,source="$(pwd)/app",target=/app \
# lambda_packager