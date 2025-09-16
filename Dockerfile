FROM alpine:3.18

RUN apk add --no-cache curl

COPY notify.sh /notify.sh
RUN chmod +x /notify.sh

CMD ["/notify.sh"]
