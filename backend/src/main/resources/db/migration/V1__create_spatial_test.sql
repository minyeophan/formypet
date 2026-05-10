-- Phase 1 공간 쿼리 검증용 테이블 (운영 배포 시 V2에서 DROP 예정)
-- MySQL 8.0.13+: SRID 4326 WKT 좌표 순서 = (위도, 경도)
CREATE TABLE IF NOT EXISTS spatial_test (
    id       BIGINT AUTO_INCREMENT PRIMARY KEY,
    name     VARCHAR(100) NOT NULL,
    location POINT        NOT NULL SRID 4326,
    SPATIAL INDEX idx_location (location)
) ENGINE = InnoDB;

INSERT INTO spatial_test (name, location) VALUES
    ('서울역',   ST_GeomFromText('POINT(37.5547 126.9726)', 4326)),
    ('강남역',   ST_GeomFromText('POINT(37.4979 127.0276)', 4326)),
    ('홍대입구', ST_GeomFromText('POINT(37.5571 126.9228)', 4326)),
    ('잠실역',   ST_GeomFromText('POINT(37.5133 127.1000)', 4326)),
    ('판교역',   ST_GeomFromText('POINT(37.3952 127.1109)', 4326));
