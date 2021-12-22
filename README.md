# SwiftLambdaProxy

A simple proxy that can convert HTTP requests to Lambda API Gateway event payloads,
forward them to a local Lambda server (for testing), and convert the response
to a regular HTTP response.

This lets you invoke the local Lambda server with tools like curl or Postman.

