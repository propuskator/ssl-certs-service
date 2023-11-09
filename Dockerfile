FROM alpine:latest

WORKDIR /app

RUN apk update && apk upgrade && apk add openssl

COPY gen.sh gen.sh
COPY openssl_template.cnf openssl_template.cnf

ENTRYPOINT ["sh", "./gen.sh"]