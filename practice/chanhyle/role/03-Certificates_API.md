## Certificates API

- 새로운 어드민 유저를 위해 증명서를 발급해야 하는 상황(클러스터에 접근하기 위해)
- 관리자(어드민)이 새로운 유저의 CSR을 전달 받음 => CA의 서명을 통해 증명서(Client Certificates) 발급 => 발급된 증명서를 새로운 유저에게 전달

### CA Server

- CA는 사실 비대칭 키와 증명서 파일이 전부
- 이 자원에 접근할 수 있는 사람은 어떤 증명서에도 서명할 수 있어, 해당 증명서를 가지고 클러스터에 접근할 수 있음
- 이 자원은 안전한 곳에 보관하고, 접근에 제한이 되어야 함 => 서명을 하기 위해서는 해당 서버에 로그인해야 함
- 이 CA(Root Certificates)는 보통 마스터 노드에 저장. 즉, 마스터 노드가 RCA 서버 역할

### Certificates API

- 위와 같은 증명서 발급 과정을 수동으로도 할 수 있지만, 더 쉬운 방법으로 증명서를 관리하고 / 서명하는 방법으로 쿠버네티스는 내장 Certificates API를 제공
- 마스터 노드에 로그인 하는 대신, 이 API를 호출하여 CSR을 넘겨주면 자동으로 처리해 줌
- CertificateSigningRequest 오브젝트 생성 필요

#### 순서

1. 새로운 유저가 key / CSR 생성
2. CertificateSigningRequest 오브젝트 yaml 파일 생성

   - kind : CertificateSigningRequest
   - spec > request : base64 encoded CSR

```shell
# base64 인코딩
$> cat Jane.csr | base64 -w 0
```

3. CertificateSigningRequest 오브젝트 생성

```shell
$> k create -f Jane-CSR.yaml
```

4. Review requests

```shell
$> k get csr
```

5. Approve requests

```shell
$> k certificate approve Jane-CSR
```

- CA 키 페어를 가지고 서명하는 단계

6. Share certificate to users

```shell
$> k get csr Jane-CSR -o yaml
```

- Status > certificate : base64 encoded Certificates
- 복사 후 base64 디코딩

```shell
$> echo "..." | base64 --decode
```

#### Certificate operated operations 와 관련된 시스템 오브젝트는?

- kube-controller manager
- 내부에 CSR-approving, CSR-signing controller가 존재

```shell
$> cat /etc/kubernetes/manifests/kube-controller-manager.yaml
```

- `-—cluster-siginig-cert-file` / `-—cluster-signing-key-file` 항목에 서명할 때 필요한 CA 파일 경로를 적어주어야 함

## 명령어 모음

```shell
$> k certificate approve akshay
$> k describe csr agent-smith
$> k get csr agent-smith -o yaml
$> k certificate deny agent-smith
$> k delete csr agent-smith
```
