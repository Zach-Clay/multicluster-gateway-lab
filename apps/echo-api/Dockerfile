FROM golang:1.25-alpine AS build
WORKDIR /src
COPY go.mod main.go ./
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /echo-api .

FROM gcr.io/distroless/static:nonroot
COPY --from=build /echo-api /echo-api
USER nonroot
EXPOSE 8080
ENTRYPOINT ["/echo-api"]
