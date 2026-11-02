# Huawei Private-Cloud Ingress Integration

The wrapper routes RP and video objects under one hostname using standard Ingress
`Prefix` matching. It does not install a cloud load balancer or guess a private-
cloud controller. This guide is a deployment checklist, **not an executed Huawei
production acceptance record**. The user-owned cluster/version, ELB and controller
credentials are not available in this local environment.

## Confirm The Platform Contract

Ask the platform team for the actual Huawei product/version (for example Huawei
Cloud Stack CCE or UCS), Kubernetes version, supported controller/class, internal
ELB/listener, service/backend requirements, DNS and TLS certificate management.

```sh
kubectl config current-context
kubectl get ingressclass -o wide
kubectl get ingress -A
kubectl get services -n reportportal
```

Public-cloud CCE documentation uses `ingressClassName: cce`; some Huawei private-
cloud/UCS documentation uses `public-elb`. These are examples of **different
platform contracts**, not interchangeable class names. Verify your actual class
and its support for `networking.k8s.io/v1`, `Prefix` matching and the two routes
sharing a hostname. Your ELB may need NodePort backends, pod-IP backends or vendor-
specific annotations. Do not change all RP Services blindly: adapt according to
the platform team's supported backend mode and test health checks.

Official references:
- [CCE ELB ingress configuration](https://support.huaweicloud.com/usermanual-cce/cce_10_0694.html)
- [Huawei private-cloud UCS guide](https://doc.hcs.huawei.com/zh-cn/ucs/doc/download/pdf/ucs-usermanual.pdf)

## Render Before Installing

Copy `values-production.example.yaml` and `values-huawei.example.yaml` into private
deployment values. Replace the explicit class placeholder in **both** RP and video
configuration. Set the hostname, TLS Secret and required ELB annotations from your
platform's documentation. Provision `rp-runtime-auth` through your secret manager;
do not put credentials in values, Git or command arguments.

```sh
helm dependency build ./helm/reportportal-rich-experience
helm lint ./helm/reportportal-rich-experience \
  -f ./production-values.yaml -f ./huawei-values.yaml
helm template reportportal ./helm/reportportal-rich-experience \
  -n reportportal -f ./production-values.yaml -f ./huawei-values.yaml \
  > ./rendered-resources.yaml
```

Inspect the rendered resources. Remove inherited `nginx.ingress.kubernetes.io/*`
annotations; setting a new class alone does not translate old vendor options.
Keep `/automation-videos` forwarded intact to MinIO: stripping that prefix removes
the bucket name and breaks path-style S3 URLs. Confirm the controller matches that
more-specific prefix ahead of RP's `/` route. HTTP `/automation-videos-other` must
not match the video bucket rule. Set timeouts/body limits in the **chosen** controller
or ELB, not in obsolete NGINX annotations. Never disable CSP as a migration shortcut.

## Cutover And Acceptance

Create a parallel internal listener/DNS name for the replacement. Keep the current
gateway available while testing. Install the wrapper with `--wait --wait-for-jobs`;
verify readiness, the bucket reconciliation Job and TLS trust.

```sh
helm upgrade --install reportportal ./helm/reportportal-rich-experience \
  -n reportportal --create-namespace \
  -f ./production-values.yaml -f ./huawei-values.yaml \
  --wait --wait-for-jobs --timeout 20m
curl --fail --head https://reportportal.internal.example/ui/
curl --fail https://reportportal.internal.example/api/info
curl --fail --head https://reportportal.internal.example/automation-videos/videos/KNOWN_RECORDING.mp4
curl --fail -H 'Range: bytes=0-63' \
  https://reportportal.internal.example/automation-videos/videos/KNOWN_RECORDING.mp4
```

The recording Range request must return 206 with `Content-Range`. Use a disposable
probe object, not a business recording, to verify anonymous PUT/DELETE return 403;
verify bucket listing is denied. A CI-authenticated uploader must still succeed.
Run the SDK's API/UI, endurance and RP-fault acceptance against the new URL. Open
RP, verify item/log ownership and play/seek a video without cross-origin/CSP errors.

Switch internal DNS/ELB traffic only after these gates pass. Preserve prior ingress
resources, controller/listener settings and DNS values for rollback. Roll back
the **routing**, not to an old Chart revision that reapplies unsafe anonymous
read/write policy. Remove the retired ingress-nginx controller only after all its
other namespaces have a tested replacement. Local Traefik success is not Huawei
ELB production certification, and this task does not migrate databases/history.
