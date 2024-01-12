## Namespaced Role

### Role 생성

```shell
$> vim developer-role.yaml
```

- kind :Role
- Rule > apiGroups: [“”]
- Rule > resources: [“pods”]
- Rule > verbs: [“create]
- Rule > resourceNames : [“blue”, “orange”] : 특정 리소스에 이름으로 포함시킬 수 있음
- cf> 여러 개의 Rule 배열을 추가할 수 있음
- 네임스페이스를 제한하고 싶으면 metadata > namespace 에 추가

### Role 추가

```shell
$> k create -f developer-role.yaml
```

### Rolebinding 생성

```shell
$> vim devuser-developer-binding.yaml
```

- 역할과 유저를 묶어주는 역할
- kind : RoleBinding
- Subjects : 묶어줄 유저를 특정
- RoleRef : 묶어줄 역할을 특정

### Rolebinding 추가

```shell
$> k create -f devuser-developer-binding.yaml
```

### 명령어 모음

```shell
$> k get roles -n blue
$> k get rolebindings
$> k describe roles
$> k describe rolebinding
# 권한이 있는지 알아보는 방법
$> k auth can-i create deployments
$> k auth can-i delete nodes
# 실행 유저가 Admin이라면 특정 유저가 권한이 있는지 알아볼 수 있음
$> k auth can-i create deployments —as dev-user
$> k auth can-i create deployments —as dev-user —namespace test

$> cat > dev-user-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default
  name: pod-reader
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["pods"]
  verbs: ["get", "watch", "list"]

# 선언형이 아닌 명령형으로 생성하는 방벙
$> k create rolebinding dev-user-binding —role=developer —user=dev-user
# 옵션을 모르겠으면?
$> k create rolebinding --help
$> k auth can-i get pods --as dev-user —namespace=blue
# edit 명령어를 이용하여 파일을 지정하지 않고 바꾸는 방법
$> k edit role developer -n blue
```

- Resource에 따라 apigroup이 바뀔 수 있음에 주의(`05-API_Groups.md` 참고)
  - Deployments 는 apigroup이 “apps”임을 주의

## Cluster-scoped Role

- 위에서 살펴본 role과 roleBinding은 사실 “네임스페이스 내부”에서 생성됨
- namespace를 지정하지 않으면 Default namespace에 생성됨(metadata)
- 노드 자원이 네임스페이스에 배타적으로 귀속될 수 있는가?
  - No
  - 노드는 Cluster-wide, Cluser-scoped resources 이기 때문
- 그래서 Resource는 namespaced / cluster-scoped로 지정될 수 있음
- Namespaced

      - Pods, Replicates, Jobs, Deployments, Services, Secrets, Roles, Rolebindings, Configmaps, PVC
      - view / delete / update 를 하려면 항상 ns를 명시

```shell
# namespaced 자원 목록 확인
$> k api-resources —namespaced=true
```

- Cluster-scoped
  - Nodes, PV, Cluster roles, Clusterrolebindings, Cerfificatesigningrequests, namespaces

```shell
# cluster-scoped 자원 목록 확인
$> k api-resources —namespaced=false
```

- ClusterRoles, ClusterRolebinding은 cluster-scoped 자원들에 인가하기 위한 방식

### ClusterRoles 생성

```shell
$> vim cluster-admin-role.yaml
```

- kind: clusterRole
- resources: [“nodes”]

### ClusterRoles 추가

```shell
$> k create -f cluster-admin-role.yaml
```

### ClusterRolebinding은 생성

```shell
$> vim cluster-admin-rolebinding.yaml
```

- kind: clusterRoleBinding

### ClusterRolebinding은 추가

```shell
$> k create -f cluster-admin-rolebinding.yaml
```

- Cluster roles, Cluster rolebinding은 namespaced-scoped resource에도 사용할 수 있다
  - cf> 모든 네임스페이스에 권한을 사용할 수 있게 된다
  - 그러기에 조심하여 사용해야 함

### 명령어 모음

```shell
$> k get clusterRoles
$> k get clusterRoleBindings
$> k describe clusterRoleBinding cluster-admin
$> k describe clusterRole cluster-admin

$> cat > developer-role.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  # "namespace" omitted since ClusterRoles are not namespaced
  name: secret-reader
rules:
- apiGroups: [""]
  #
  # at the HTTP level, the name of the resource for accessing Secret
  # objects is "secrets"
  resources: ["secrets"]
  verbs: ["get", "watch", "list"]

$> k create -f developer-role.yaml

$> kubectl api-resources
$> kubectl api-resources | grep "storageclasses"
$> kubectl api-resources | grep "persistentvolumes"

$> k get nodes —as Michelle
```
