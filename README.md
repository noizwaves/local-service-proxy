# local-service-proxy

Run in-container localhost proxies direct to Kubernetes services.

## Usage

Ensure that the service account being used has permission to list services.
To add this to the default service account:
```bash
kubernetes create role service-discovery --verb=list --resource=services
kubernetes create rolebinding default-service-discovery --role=service-discovery --serviceaccount=$NAMESPACE:default
```

Add `local-service-proxy` as a sidecar to the application container that needs to proxy out and set `ALLOW_LIST` to govern what services are proxied:
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  ...
  template:
    spec:
      containers:
        - name: foo-web
          ...
        - name: local-service-proxy
          image: noizwaves/local-service-proxy:latest
          env:
            - name: ALLOW_LIST
              value: "bar-web baz-web quux-web"
```