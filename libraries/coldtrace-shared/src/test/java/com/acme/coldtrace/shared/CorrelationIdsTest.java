package com.acme.coldtrace.shared;

import static org.assertj.core.api.Assertions.*;

import org.junit.jupiter.api.Test;

public class CorrelationIdsTest {
  @Test
  void safeCorrelationSurvivesPropagation() {
    assertThat(CorrelationIds.sanitize("tp1-retry-001")).isEqualTo("tp1-retry-001");
  }

  @Test
  void unsafeAndOversizedIdsAreReplaced() {
    assertThat(CorrelationIds.sanitize("x\nforged")).doesNotContain("\n");
    assertThat(CorrelationIds.sanitize("x".repeat(65))).hasSize(36);
  }
}
