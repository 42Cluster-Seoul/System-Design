## API Groups

- 쿱에서는 여러 API가 존재

```shell
# 파드 정보 가져오기
$> curl https://kube-master:6443/api/v1/pods

# 버전 가져오기
$> curl https://kube-master:6443/version
```

- 종류

  - /metrics : 클러스터의 상태를 보여줌
  - /healthz : 클러스터의 상태를 보여줌
  - /version : 클러스터의 버전을 보여줌
  - /api : core group
  - /apis : named group
  - /logs : 써드 파티 로깅 애플리케이션을 통합함

### /api

- core group
- /api/v1 아래
- /namespaces, /pods, /rc, /services, /nodes, /bindings 등이 존재

### /apis

- named group
- /apis 아래
- /apps, /extensions, /networking.k8s.io, /certificiates.k8s.io 등… => **API groups**
- API groups 아래 v1 아래
  - /deployments, /replicasets 등… => **Resources**
  - Resources 아래
    - /list, /get, /create, /delete, /update, /watch => **Verbs**
- **API groups** > **Resources** > **Verbs**

```shell
# API groups view
$> curl http://localhost:6443 -k

# Resource group view
$> curl http://localhost:6443/apis -k | grep “name”
```

- 자동으로 인증(authentication)이 되지 않는 경우, 권한이 없는 경우 —-key, —-cert, -—cacert를 이용하여 시도
- Kubectl proxy를 이용하여 Kube apiServer를 우회하는 접근하는 방법
  - Kube proxy : 파드와 서비스를 노드 위치와 관계없이 연결해주는 것
  - Kubectl proxy : kube apiServer에 접근하기 위해 생성하는 프록시
