# 포마펫 백엔드 모니터링 운영

Railway의 Spring Boot가 Prometheus 형식의 지표를 제공하고 Grafana Cloud Metrics Endpoint가 HTTPS로 1분마다 수집한다. Alloy, 별도 Prometheus 서버, 새 DB/볼륨은 사용하지 않는다. 운영 변경은 아래 배포 전 점검과 사용자 확인 이후에 수행한다.

## 확인한 현재 상태 (2026-10-03)

| 항목 | 확인 결과 |
| --- | --- |
| 코드 기준 | `origin/develop`의 `3be8128`, Java 21 / Spring Boot 3.4.1 |
| 작업 브랜치 | `feat/grafana-monitoring` |
| Railway 운영 커밋 | `5b54792d8b93f1a43e28e662082d03885683006b` |
| 운영 배포 | GitHub `main` 자동 배포, 루트 `/backend` |
| 빌드 | Railpack, 배포 상세 표시 Java 21.0.2 / Gradle 8.14.5 |
| 실행 | `java -jar build/libs/formypet-0.0.1-SNAPSHOT.jar` |
| 네트워크 | `https://formypet-production-production.up.railway.app`, 대상 포트 8080 |
| 배치 | 동남아시아, 1 replica, Serverless 꺼짐 |
| 배포 보호 | Wait for CI 꺼짐, Healthcheck Path 미설정 |
| 재시작 | On Failure, 최대 10회 |

위 값은 읽기 전용으로 확인한 스냅샷이다. 배포 직전에 다시 확인한다. 당시 `main`과 `develop`의 `backend` 내용은 같았다. 프런트엔드 차이가 있으므로 `develop` 전체를 운영에 합치지 않는다. 앱의 `API_BASE_URL`은 빌드 시 정해지지만 이번 변경은 주소·API 계약을 유지하므로 신규 AAB 배포가 필요하지 않다.

기존 운영 로그에 Firebase 자격 증명 파일 누락으로 푸시가 비활성화됐다는 경고가 있다. 이번 변경으로 발생한 문제가 아니며 파일 설정을 변경하지 않는다. 실제 푸시 검증은 이 기존 상태를 해결하거나 현 상태를 명시적으로 수용하기 전까지 **미완료**로 기록한다. MySQL 9.7에 대한 Flyway 지원 범위 경고도 관찰됐으며 이번 작업에서 DB 버전이나 마이그레이션을 변경하지 않는다.

Railway 화면은 Trial이며 27일 또는 $3.83 잔여로 표시됐다. Grafana Free와 별개의 Railway 운영 비용/만료 조건이다. 유료 전환은 자동으로 수행하지 않는다.

## 설정과 보안

| 환경 변수 | 기본값 | 운영 설정 |
| --- | --- | --- |
| `MONITORING_ENABLED` | `false` | 활성화 승인 이후 `true` |
| `MONITORING_USERNAME` | 없음 | 이 용도로만 사용하는 사용자명, `:` 제외 |
| `MONITORING_PASSWORD` | 없음 | 비밀 관리 도구에서 생성한 충분히 긴 무작위 값 |
| `MONITORING_ENVIRONMENT` | `local` | `production` |

인증값은 Railway 서비스의 비밀 환경 변수와 Grafana 수집 작업 인증 설정에만 입력한다. `.env` 파일, 셸 인수/기록, 이 문서, 스크린샷, 테스트 로그에 운영 인증값을 넣지 않는다. 활성화 시 사용자명/비밀번호가 비어 있으면 애플리케이션 시작을 거부한다. 비밀 설정부터 준비하고 활성화를 마지막에 적용한다.

- `GET /actuator/prometheus`만 전용 Basic 인증으로 접근한다. HTTPS 인증서 검증을 유지한다.
- 앱 JWT로 메트릭에 접근할 수 없으며, 모니터링 인증으로 보호된 앱 API를 호출할 수 없다.
- 다른 Actuator 경로와 HTTP 메서드는 차단한다. `/api/v1/health`와 기존 앱 인증은 유지한다.
- 외부 설정으로 Actuator를 앱 공개 경로 밑으로 옮겨도 실제 엔드포인트를 먼저 차단한다. 지원하는 수집 경로는 기본 `/actuator/prometheus`이며 변경한 경로로는 수집하지 않는다.
- 모니터링 기능을 끄면 Prometheus 엔드포인트와 exporter가 비활성화된다. 일부 로컬 계측 자체의 비용까지 모두 없어지는 것은 아니다.
- 기본 Actuator 노출과 JMX 노출을 제한한다. HTTP client·보안 내부·디스크 경로 등 불필요한 지표는 export하지 않는다.
- 사용자명과 인증 공급자는 메트릭 보안 체인 내부에만 존재한다. `JwtAuthFilter`는 앱 보안 체인에서만 실행한다.

## 지표와 해석

`service="formypet"`, `environment`와 Grafana의 `job`으로 운영 대상을 구분한다. 경로는 `/api/v1/pets/{id}` 같은 템플릿이다. 라우팅 전 인증 거부는 `AUTHENTICATION`, 미매칭은 `UNMATCHED`로 제한한다. 원본 URL·쿼리·사용자 식별자를 라벨로 넣지 않는다. 헬스체크·문서·메트릭 요청은 API 지표에서 제외한다.

HTTP 지표는 `http_server_requests_seconds_count`, `_sum`, `_bucket`을 사용한다. 상태 코드로 오류를 집계해 처리된 예외 응답도 포함한다. 고정 버킷은 25/50/100/250/500ms, 1/2/5/10/30s와 `+Inf`이며 자동 버킷과 클라이언트 percentile을 추가하지 않는다. 버킷 라벨의 `1`/`1.0`, `30`/`30.0` 표현을 모두 처리한다.

- RPS·평균·오류율·1초 초과 비율: 최근 5분. p95/p99: 최근 15분과 표본 수.
- 오류가 없으면 0%, 요청이 없으면 비율/지연은 데이터 없음과 별도 `요청 없음` 표시. 수집 실패는 별도 `수집 중단 / 미연결` 표시.
- 최근 JVM 표본이 150초 이내면 최근 수집 정상으로 판단한다. 이것은 개별 scrape 성공 코드가 아니며 서버 생존을 보장하지 않는다. 정확한 수집기 오류는 Metrics Endpoint Overview에서 확인한다.
- p95/p99는 버킷 사이 보간치다. 요청이 적거나 지연이 30초를 넘으면 해석에 주의하고 30초 초과 비율을 함께 본다.
- 카운터별 rate/increase를 계산한 뒤 합산한다. 재시작 초기화는 처리하나 첫 수집 이전이나 재시작 직전의 미수집 증가는 복구하지 못한다. 요청 수는 운영 추정치이며 소수점이 가능하다.
- Railway 앞단 502/504, 앱 네트워크 오류, 사용자 행동은 백엔드 HTTP 지표에 포함되지 않는다.
- JVM 스레드 패널은 플랫폼 스레드 지표이며 전체 가상 스레드 수가 아니다. Hikari 패널은 연결 풀 상태이며 DB 서버 자체의 CPU/느린 SQL 분석은 아니다.
- 한 인스턴스를 전제로 한다. 여러 replica를 공용 주소로 번갈아 수집하면 카운터가 섞인다. 증설 전 인스턴스별 수집 설계를 바꾼다. 롤링 배포 중 겹치는 구간도 불확실하므로 배포 시간을 annotation으로 기록한다.

## 로컬·CI 검증

저장소 루트에서 실행한다. 백엔드 전체 테스트에는 Docker와 테스트용 MySQL 컨테이너가 필요하며 운영 DB를 사용하지 않는다.

```powershell
.\backend\gradlew.bat -p backend test bootJar --no-daemon
python ops/monitoring/test_dashboard.py <promtool.exe의-절대경로>
```

Linux CI에서는 기존 `./gradlew test`와 별도 Monitoring dashboard PromQL job이 실행된다. promtool은 공식 Prometheus 3.15.0 릴리스와 SHA-256 검증을 사용한다. 별도 Prometheus 서버를 운영하는 것이 아니라 테스트 실행 파일만 사용한다.

HTTP 테스트는 실제 임베디드 서버에서 Basic/JWT 상호 격리, 비활성화, 누락된 인증 설정, 다른 경로/메서드 차단, 처리된 400/401/403/404/500, 버킷·1초 경계, 개인정보와 시계열 수를 검증한다. 별도 MySQL 통합 테스트는 실제 애플리케이션의 Hikari 지표를 검증한다. 쿼리 테스트는 JSON의 실제 PromQL을 추출하여 무데이터·무요청·오류 0건·5xx·재시작·수집 중단·지연을 검증한다.

## 배포 및 Grafana 연결 — 사용자 확인 후

1. 배포 직전 커밋, 연결 브랜치, 단일 replica, Serverless 꺼짐을 재확인한다. 기존 환경 변수 상태를 비밀 관리 도구에 기록한다. 비밀값을 Git에 백업하지 않는다.
2. 변경 목록과 테스트를 검토하고 DB 마이그레이션/Flutter 변경이 없는지 확인한다. `main`용 릴리스에는 모니터링 커밋만 반영하고 해당 최종 커밋에서 CI를 통과시킨다. Wait for CI가 꺼져 있으므로 검사 전에 main을 갱신하지 않는다.
3. 비용/재시작 영향과 복구 대상을 제시하고 운영 적용 확인을 받는다. Healthcheck Path를 `/api/v1/health`로 설정하는 제안도 이때 포함한다. 이 경로는 단순 응답 확인이며 DB 준비 상태 검사는 아니다. 설정 변경을 승인 없이 수행하지 않는다.
4. 비밀 환경 변수와 코드 배포를 반영한다. 새 버전 시작, 기존 health와 로그인 API를 확인한다. 앱 서버 재시작으로 짧은 연결 끊김이 가능하다.
5. `/actuator/prometheus`가 무인증/앱 JWT에는 401, 올바른 Basic 인증에는 200인지 확인한다. 리다이렉트 없는 유효한 공개 HTTPS URL이어야 한다. 다른 Actuator 경로는 접근되지 않아야 한다. 비밀번호를 명령줄에 쓰는 `curl -u user:password` 예시는 사용하지 않는다.
6. `https://grayash2385.grafana.net` → Connections → Metrics Endpoint에 접속한다. job `formypet-production`, URL `https://formypet-production-production.up.railway.app/actuator/prometheus`, Every minute, Basic을 설정한다. Test Connection 성공 뒤 Save한다. **Save 즉시 수집이 시작된다.**
7. 해당 integration의 Install로 Metrics Endpoint Overview를 추가한다. `ops/monitoring/formypet-dashboard.json`을 Import하고 기존 Grafana Cloud Prometheus 데이터 소스를 선택한다. service=`formypet`, environment=`production`, job=`formypet-production`을 확인한다. 새 데이터 소스나 유료 구독은 만들지 않는다.
8. 라벨·풀 이름·버킷과 패널이 실제 데이터에 맞는지 확인한다. 이미 등록된 타깃을 중복 수집하지 않는다. 1분 수집에서는 첫 rate 표시까지 여러 표본이 필요하다. 기본 조회는 최근 6시간이며 5분 이상으로 조회한다.
9. 기존 Play 비공개 테스트 앱과 테스트 계정으로 카카오·이메일 로그인, 사진 업로드/조회, 주요 API와 푸시를 확인한다. 실제 사용자에게 푸시나 테스트 데이터를 보내지 않는다. 푸시의 기존 비활성화 상태는 별도로 기록한다.
10. 30분 수집과 패널을 확인한 뒤 24~48시간 후 사용량·시계열을 수동 점검한다. 자동 알림/예약 점검은 이번 범위에 없다. 모든 운영 검증 전에는 배포·안정화 완료로 표시하지 않는다.

## 사용량과 비용

Grafana Cloud Free는 현재 활성 시계열 10,000개와 14일 보존을 제공한다. 체험판 추가 한도는 제외하고, 이 서비스는 초기 5,000개 이하를 목표로 한다. 시작 직후 수치는 부족하므로 주요 API/응답 상태를 확인한 뒤 실제 활성 시계열을 확인한다. 스택에 다른 서비스가 있으면 한도를 공유한다. 대시보드의 현재 시계열 수와 청구용 활성 시계열은 다르며 **Grafana Usage 화면을 최종 기준**으로 한다.

1분 간격은 30일에 43,200번 수집한다. 응답 크기 × 43,200으로 월 전송량을 추산하고 Railway 실제 청구와 비교한다. 예를 들어 응답 50KB라면 약 2.16GB/월이며 이것은 네트워크 양의 예시이지 실제 비용 측정값이 아니다. CPU(Basic 인증 포함), 히스토그램 메모리, 전송량이 추가될 수 있어 총비용 0원을 보장하지 않는다. 별도 수집기 서버 비용은 없다.

반영 전/후 같은 길이 구간의 Railway CPU·메모리·egress와 Grafana Usage를 기록한다. 불필요한 라벨과 지표를 줄이는 것을 먼저 검토하고, 한도 접근 시 수집 중지 또는 범위 축소 후 확인받는다. 자동 유료 전환은 하지 않는다. 현재 Railway Trial 만료와 잔액도 별도 확인한다.

## 인증정보 교체와 롤백

인증정보 교체: 짧은 수집 공백을 허용하고 Grafana job 중지 → Railway 비밀값 교체 및 재배포 → Grafana 인증값 교체 → Test Connection → 수집 재개 순서로 진행한다. 앱 JWT와 사용자 비밀번호는 변경하지 않는다. 교체 전후 기존 앱 기능을 확인한다.

롤백: Grafana 수집 중지 → `MONITORING_ENABLED=false` 반영 → 필요하면 기록한 이전 Railway 배포로 복구 → 관련 환경 변수와 승인받아 변경했던 헬스체크 설정을 이전 상태로 복원한다. 코드 롤백이 환경 변수까지 되돌린다고 가정하지 않는다. health·로그인·주요 API를 확인하고 롤백 시간을 기록한다. DB 변경이 없으므로 이번 기능 롤백에 DB 복구는 필요하지 않다. Grafana에 이미 저장된 지표는 보존 기간까지 남는다.

## 참고

- [Grafana Metrics Endpoint 요구사항과 수집 간격](https://grafana.com/docs/grafana-cloud/observe-and-act/monitor-infrastructure/integrations/integration-reference/integration-metrics-endpoint/)
- [Grafana Cloud 가격과 Free 한도](https://grafana.com/pricing/)
- [Railway 요금](https://docs.railway.com/pricing)
- [Micrometer 히스토그램](https://docs.micrometer.io/micrometer/reference/concepts/histogram-quantiles.html)
- [Prometheus rate/increase와 histogram_quantile](https://prometheus.io/docs/prometheus/latest/querying/functions/)

### Grafana Cloud 작업 라벨

Metrics Endpoint의 실제 `job` 라벨은 `integrations/metrics_endpoint/<id>-metrics-endpoint-formypet-production` 형태일 수 있습니다. 대시보드 job 목록에서 실제 값을 선택합니다. job은 단일 선택이므로 PromQL에서 `job="${job}"`로 비교합니다. `${job:regex}`는 슬래시를 잘못 이스케이프해 조회 오류를 만들 수 있으므로 사용하지 않습니다.
