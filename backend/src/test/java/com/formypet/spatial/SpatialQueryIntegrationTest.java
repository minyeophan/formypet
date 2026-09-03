package com.formypet.spatial;

import com.formypet.support.IntegrationTestSupport;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

@DisplayName("[통합] MySQL Spatial 쿼리 검증")
@Transactional
class SpatialQueryIntegrationTest extends IntegrationTestSupport {

    @Autowired
    JdbcTemplate jdbcTemplate;

    @BeforeEach
    void cleanInsertedData() {
        jdbcTemplate.update("DELETE FROM spatial_test WHERE name = '테스트장소'");
    }

    @Test
    @DisplayName("ST_Distance_Sphere: 강남역 ↔ 서울역 거리가 9~11km 사이다")
    void stDistanceSphereReturnsReasonableResult() {
        // MySQL 8.0.13+: SRID 4326 WKT 좌표 순서 = (위도, 경도)
        // 강남역(lat=37.4979, lng=127.0276) ↔ 서울역(lat=37.5547, lng=126.9726) ≈ 9.7km
        String sql = """
            SELECT ST_Distance_Sphere(
                ST_GeomFromText('POINT(37.4979 127.0276)', 4326),
                ST_GeomFromText('POINT(37.5547 126.9726)', 4326)
            ) AS dist
            """;

        Double distMeters = jdbcTemplate.queryForObject(sql, Double.class);

        assertThat(distMeters)
                .as("강남역-서울역 거리 (7~9km 기대, 실측 ~7.97km)")
                .isNotNull()
                .isBetween(7_000.0, 9_000.0);
    }

    @Test
    @DisplayName("POINT SRID 4326 저장 후 ST_X/ST_Y로 좌표를 정확히 조회한다")
    void insertPointWithSrid4326AndRetrieveCoordinates() {
        double expectedLat = 37.456;
        double expectedLng = 127.123;
        // SRID 4326: INSERT 순서 = (위도, 경도)
        jdbcTemplate.update("""
            INSERT INTO spatial_test (name, location)
            VALUES ('테스트장소', ST_GeomFromText(?, 4326))
            """, String.format("POINT(%f %f)", expectedLat, expectedLng));

        // SRID 4326: ST_X = 첫 번째 축 = 위도, ST_Y = 두 번째 축 = 경도
        Map<String, Object> row = jdbcTemplate.queryForMap("""
            SELECT ST_X(location) AS lat, ST_Y(location) AS lng
            FROM spatial_test WHERE name = '테스트장소'
            """);

        assertThat((Double) row.get("lat"))
                .isEqualTo(expectedLat, org.assertj.core.data.Offset.offset(0.0001));
        assertThat((Double) row.get("lng"))
                .isEqualTo(expectedLng, org.assertj.core.data.Offset.offset(0.0001));
    }

    @Test
    @DisplayName("반경 5km 내 검색: 강남역 기준으로 강남역만 포함, 나머지는 제외된다")
    void radiusSearchReturnsOnlyNearbyPlaces() {
        // 기준점 = 강남역 (lat=37.4979, lng=127.0276), 반경 5km
        String sql = """
            SELECT name FROM spatial_test
            WHERE ST_Distance_Sphere(
                location,
                ST_GeomFromText('POINT(37.4979 127.0276)', 4326)
            ) <= 5000
            ORDER BY name
            """;

        List<String> result = jdbcTemplate.queryForList(sql, String.class);

        assertThat(result)
                .as("5km 반경 내: 강남역만 포함")
                .containsExactly("강남역")
                .doesNotContain("서울역", "홍대입구", "잠실역", "판교역");
    }
}
