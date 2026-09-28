package com.formypet.auth;

import java.security.Principal;

/** Identity remains bound to one database account even if its email is reused. */
public record AuthenticatedUser(long id, long version) implements Principal {
    public AuthenticatedUser {
        if (id <= 0 || version < 0) throw new IllegalArgumentException("Invalid identity");
    }
    @Override public String getName() { return Long.toString(id); }
}
