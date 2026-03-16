FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    bash \
    && curl -sSL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 -o /usr/local/bin/ttyd \
    && chmod +x /usr/local/bin/ttyd \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /game

COPY dockermaster.sh /game/dockermaster.sh
RUN chmod +x /game/dockermaster.sh

EXPOSE 7681

CMD ["ttyd", "--port", "7681", "--writable", "bash", "/game/dockermaster.sh"]
