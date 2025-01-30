FROM golang:1.21 as build
ENV GO111MODULE=on
WORKDIR /
COPY . .
RUN go get -d -v ./...
RUN CGO_ENABLED=0 go build -o /bin/jwt jwt.go

# Unprivileged users can execute
RUN chgrp 0 /bin/jwt 
RUN chmod g+x /bin/jwt 

FROM scratch
COPY --from=build /bin/jwt  .
USER 65534
CMD ["/jwt"]