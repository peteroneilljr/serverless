FROM node:12

# COPY /app /app
# RUN apt-get update -y
# RUN apt-get install zip -y
RUN mkdir /app
WORKDIR /app

CMD npm install && npm start

# Run docker with current files
# docker build -t node_site .
# docker run -it --rm \
#   --name node_site  \
#   --mount type=bind,source="$(pwd)/app",target=/app \
#   --publish=8100:8100 \
# node_site