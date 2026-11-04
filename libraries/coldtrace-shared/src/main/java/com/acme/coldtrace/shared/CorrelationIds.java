package com.acme.coldtrace.shared;

import java.util.UUID;
import java.util.regex.Pattern;

public final class CorrelationIds {
  private static final Pattern SAFE = Pattern.compile("[A-Za-z0-9._-]{1,64}");

  private CorrelationIds() {}

  public static String sanitize(String supplied) {
    return supplied != null && SAFE.matcher(supplied).matches()
        ? supplied
        : UUID.randomUUID().toString();
  }
}
