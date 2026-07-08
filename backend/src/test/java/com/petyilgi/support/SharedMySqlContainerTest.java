package com.petyilgi.support;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SharedMySqlContainerTest {

    @Test
    void sharesOneRunningContainerWithinTheTestJvm() {
        var first = SharedMySqlContainer.getInstance();
        var second = SharedMySqlContainer.getInstance();

        assertSame(first, second);
        assertTrue(first.isRunning());
    }
}
