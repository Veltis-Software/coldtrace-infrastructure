package com.acme.coldtrace.shared;

import java.util.List;

public record IdentitySession(Long userId, Long organizationId, String fullName, List<String> permissions) {
  public boolean permits(String permission) {
    return permissions != null && permissions.contains(permission);
  }
}
