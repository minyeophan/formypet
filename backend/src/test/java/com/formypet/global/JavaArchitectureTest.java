package com.formypet.global;

import org.junit.jupiter.api.Test;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import static org.assertj.core.api.Assertions.assertThat;

/** Source-level boundaries complement behavior tests during future refactors. */
class JavaArchitectureTest {
    private List<Path> sources() throws Exception {
        try (var paths = Files.walk(Path.of("src/main/java/com/formypet"))) {
            return paths.filter(path -> path.toString().endsWith(".java")).toList();
        }
    }

    @Test
    void allProductionPackagesBelongToDomainOrGlobalExceptApplicationEntryPoint() throws Exception {
        for (Path file : sources()) {
            if (file.getFileName().toString().equals("FormypetApplication.java")) continue;
            assertThat(Files.readString(file)).as(file.toString())
                    .containsPattern("package com\\.formypet\\.(domain|global)\\.");
        }
    }

    @Test
    void directDatabaseAccessRemainsInRepositoryPackages() throws Exception {
        for (Path file : sources()) {
            if (file.toString().replace('\\', '/').contains("/repository/")) continue;
            assertThat(Files.readString(file)).as(file.toString())
                    .doesNotContain("JdbcTemplate", "EntityManager", "ResultSet", "RowMapper")
                    .doesNotContainPattern("(?i)\\\"\\s*(SELECT\\s|INSERT\\s+INTO\\s|UPDATE\\s+\\w+\\s+SET\\s|DELETE\\s+FROM\\s)");
        }
    }

    @Test
    void entitiesDoNotDependOnApiDtoOrControllers() throws Exception {
        for (Path file : sources()) {
            if (!file.toString().replace('\\', '/').contains("/entity/")) continue;
            assertThat(Files.readString(file)).as(file.toString())
                    .doesNotContainPattern("import [^;]+\\.(dto|controller)\\.");
        }
    }
}
