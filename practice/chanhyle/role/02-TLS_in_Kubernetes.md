## TLS certificates in Kubernetes Cluster

### Root Ceritificates

- Server certificates를 서명할 때 쓰임
- 특정 증명서가 루트 증명서로 서명했는지 안했는지를 확인할 수 있다

### Server Certificates

- 서버가 자신을 증명하기 위해 사용
- 서버가 비대칭키를 이용하여 보안적으로 클라이언트와 소통할 때 필요한 인증서
- 서버가 클라이언트에 자신의 퍼블릭 키를 보낼 때, 해당 키가 내장된 루트 인증서로부터 서명 받은 인증서를 보낸다!

### Client Certificates

- 클라이언트가 자신을 증명하기 위해 사용(즉, 서버가 클라이언트에게 자신을 요구하라고 할 때 사용)
- 이 개념들이 쿠버네티스 클러스터와 어떻게 연관되어 있나?

  - 노드와 마스터 노드 간의 소통은 암호화되어야 함
  - 또한, kubectl 혹은 직접 쿱 API를 이용하여 쿱 클러스터와 소통하려하면 TLS 커넥션을 맺어야 함
  - 즉, 클러스터 내 다양한 서비스들 간에 각자 누가 누구인지를 입증하기 위해서! 서버 인증서(서버에게), 클라이언트 인증서(클라이언트에게)가 필요함

### 예시

1. kube-apiserver

- 다른 쿱 오브젝트, 외부 사용자들에게 클러스터를 관리하기 위해 여러 HTTPS service를 제공하므로 TLS 커넥션이 필요
- 서버 입장으로서 필요 : server certification(apiserver.crt, apiserver.key)
- 클라이언트 입장으로서 필요

  1.  kubectl or API를 사용하는 “administrators”(외부 사용자) : admin.crt, admin.key
  2.  “kube-scheduler”

      - 스케줄링이 필요한 파드를 찾기 위해 apiServer에 요청
      - scheduler.crt, scheduler.key

  3.  kube-controller-manager : contoller-manager.crt, controller-manager.key

  4.  kube-proxy : kube-proxy.crt, kube-proxy.key

2. ETCD server

- 클러스터의 모든 정보를 포함
- 서버 입장으로서 필요 : etcdserver.crt, etcdserver.key
- 클라이언트 입장으로서 필요

  - kube-apiserver
    - Etcd 서버와 소통하는 유일한 클라이언트
    - crt, key는 서버 입장으로서 이미 생성된 것을 사용 or 클라이언트용으로 따로 생성해도 됨(apiserver-etcd-client.crt, apiserver-etcd-client.key)

3. Worker node(kubelet server)

- apiServer와 대화하기 위한 kubeHTTPS API 엔드포인트를 expose
- 서버 입장으로서 필요 : kubelet.crt, kubelet.key
- 클라이언트 입장으로서 필요

  - kube-apiserver
    - 마찬가지로 서버용을 재사용해도 되고 클라이언트용으로 생성해도 됨(apiserver-kubelet-client.crt, apiserver-kubelet-client.key)
    - 다른 증명서도 마찬가지이지만, CA가 모든 증명서에 서명해야 함

- 반드시 CA(루트 증명서)가 한 개일 필요는 없음
- 하지만 클러스터에 최소한 하나의 CA를 가지도록 해야 함
- e.g. Etcd 증명서 예시

## How to create certificates

- EASYRSA / CFSSL / **_OPENSSL_**

### 1. Root Certificates

```shell
# 1. Generate keys
$> openssl genrsa -out ca.key 2048
# 2. CSR(서명을 위한 요청서) : 위에서 생성한 Private key를 동봉
$> openssl req -new -key ca.key -subj “/CN=KUBERNETES-CA” -out ca.csr
# 3. Sign
$> openssl x509 -req -in ca.csr -signkey ca.key -out ca.crt
```

- Self-Signed-Certificate(SSC)
- 자신이 생성한 private key로 자신의 증명서에 서명(특별함, 기준이 되는 증명서)
- 이후 모든 증명서에 이 키로 서명할 예정

### 2. Client Certificates

```shell
# 1. Generate keys
$> openssl genrsa -out admin.key 2048
# 2. CSR
$> openssl req -new -key admin.key -subj “/CN=kube-admin/O=system:masters” -out admin.csr
#3. Sign
$> openssl x509 -req -in admin.csr -CA ca.crt -CAkey ca.key -out admin.crt
```

- CN : kubectl 명령어를 입력하면 audit log에 적히는 이름
- O : 그룹 지정
- Root Certificate으로 서명 => 클러스터 안에서 유효한 증명서가 됨
- 증명서에 group detail()을 추가!
  - e.g. system:masters 그룹은 어드민 권한(authorization)이 있는 그룹
- apiServer에 접근하는 모든 다른 컴포넌트, 유저 : 위와 같은 방법으로 증명서를 발급할 수 있음
- kube-scheduler / kube-controller-manager / kube-proxy
  - 쿠버네티스 컨트롤 플레인에 한 부분으로 “시스템 컴포넌트”
  - prefix로 SYSTEM을 추가해주자

1. 이 증명서는 REST API 호출에서 username, password를 대체할 수 있음

```shell
$> curl https://kube-apiserver:6443/api/v1/pods —key admin.key —cert admin.crt —cacert ca.crt
```

2. 또한, kube-config.yaml 설정 파일(각각의 오브젝트 설정 파일)에서 설정하는 방법이 있음

- 브라우저에서 CA Root Certificates들을 가지고 있어서 서버를 검증하는 것처럼
- 서버 혹은 클라이언트 증명서를 사용할 때, 오브젝트(컴포넌트) 설정 파일 CA Root Certificate를 특정해주어야 함

### 3. Server Certificates

#### ETCD server

#### kube-api server

```shell

# 1. Generate keys
$> openssl genrsa -out apiserver.key 2048
# 2. CSR
$> openssl req -new -key apiserver.key -subj “/CN=kube-apiserver” -out apiserver.csr
# 3. Sign
$> openssl x509 -req -in apiserver.csr -CA ca.crt -CAkey ca.key -out apiserver.crt
```

- 여러 이름(alternative name)으로 apiServer를 사용할 수 있기 때문에(그룹?), 증명서에 해당 이름을 명시해주어야 함
- openssl.conf > alt_name에 DNS.1="", DNS.2="" 추가

#### kubelet server

- "각 노드"에서 실행되는 HTTPS API 서버
- 각각의 노드마다 증명서와 키가 필요함
- 증명서의 이름은? 모두 kubelet이 아니라 node01, node02 …
- Kubelet config file에서 Root Certificate와 Node (Server) Certificate를 명시해주어야 함(모든 노드에서)
- apiServer는 어떤 노드가 인증할지 알아야 한다 => 그룹 이름(O=)을 정해진 형식을 따름
  - system:node:node01, node02 …

## View Certificate Details

- 전체 클러스터에서 모든 증명서에 대한 헬스 체크를 해야 한다
- 어떻게?

### 1. 어려운 방법

- 모든 증명서를 일일이 발급하는 방법 : 이전 강의에서 했던 것처럼
- kubernetes-key.pem을 일일이 넣어주는 방법

```shell
$> vim /etc/systemd/system/kube-apiserver.service
# —tls-cert-file=/var/lib/kubernetes/kubernetes.pem 추가
# —tls-private-key-file=/…/ 추가
```

### 2. kubeadm

- 자동 생성

```shell
$> vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

- kube-apiServer를 위한 configuration 파일
- Etcd, kube-scheduler 등 system component config 설정 가능
- apiServer가 사용하는 모든 증명서에 대한 모든 정보를 담아줄 수 있음

### 3. 증명서 decode

```shell
$> openssl x509 -in /etc/kubernetes/pki/apiserver.crt -text -noout
```

- pki 파일들을 모아 놓은 디렉토리 : `/etc/kubernetes/pki`
- 증명서를 텍스트로 해독하고 자세한 사항을 보기 위한 명령어
- subject(증명서 이름), alternative name(별명), issuer 등에 대한 정보

## 명령어 모음

```shell
$> cat /etc/kubernetes/pki/apiserver.crt

$> openssl x509 -in apiserver.crt -text -noout

# certificates path를 알 수 있음
$> cat /etc/kubernetes/manifests/kube-apiserver.yaml
```

- 컴포넌트의 관계(서버, 클라이언트)가 정해져 있기 때문에, 서버/클라이언트 증명서를 추론할 수 있음
