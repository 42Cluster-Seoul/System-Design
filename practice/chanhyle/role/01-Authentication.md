### <전제>

- 위와 같은 모든 "유저 접근"은 kube-apiServer에 의해 관리됨
- 1. kubectl command
  ```shell
  $> k create serviceaccount sa1
  $> k get serviceaccount
  ```
- 2. REST API
  ```shell
  $> curl https://kube-server-ip:6443
  ```
- 어떤 방식으로든 모든 요청은 kube-apiServer로 간다
- apiServer는...
  - 1. 요청을 authenticate(인증)
  - 2. authorize(인가, 승인)
  - 3. 요청을 처리함

### <Authentication methods>

- 인증 방법

1.  Static password files(w/ username)

    - csv 파일에 user/pw를 저장하는 방법
    - `--basic-auth-file=user-details.csv`를 추가하는 두 가지 방법
      - 1.  kube-apiserver.service 파일에 추가(kube-apiserver 재시작 필요)
      - 2.  /etc/kubernetes/manifests/kube-apiserver.yaml에 spec > containers > command 에 추가

    ```c
    	// User-details.csv
         Password | username | userID
         password123, user1, u0001
    ```

    - 사용법

    ```shell
      $> curl -v -k https://localhost:6443/api/v1/pods -u “user1:password123"
    ```

2.  Static token file

    - 위와 같지만 `--token-auth-file=user-token-details.csv`을 추가하면 됨
    - csv에서도 패스워드 대신, 토큰 값으로 대체
    - 쉽지만 안전하지 않기 때문에 위의 두 개는 추천하지 않음
    - Auth file을 넘기기 위해 volume mount가 필요

    - 사용법

    ```shell
      $> curl -v -k https://localhost:6443/api/v1/pods --header "Authorization: Baearer Kp..."
    ```

3.  Certificates

    - 증명서를 이용하여 암호화하는 방법

4.  Third party authentication protocol(LDAP, Kerberos …)

    - 서드 파티 툴을 이용하여 인증 과정을 대신 처리하게 함
