FROM alpine:3.18

# Install required packages: curl for API calls, jq for JSON parsing
RUN apk add --no-cache curl jq

COPY notify.sh /notify.sh
RUN chmod +x /notify.sh

CMD ["/notify.sh"]
