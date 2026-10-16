package com.formypet.domain.auth.security;

import lombok.RequiredArgsConstructor;
import com.formypet.domain.auth.entity.SessionSnapshot;
import com.formypet.domain.auth.repository.jdbc.SessionSnapshotRepository;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Component;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class SessionGuard {
    private final SessionSnapshotRepository snapshots;
    public Optional<SessionSnapshot> find(String email){return snapshots.findByEmail(email);}
    public Optional<SessionSnapshot> find(long id){return snapshots.findById(id);}
    public SessionSnapshot lock(String email){return snapshots.lockByEmail(email).orElseThrow(SessionGuard::invalid);}
    public SessionSnapshot lock(long id){return snapshots.lockById(id).orElseThrow(SessionGuard::invalid);}
    public boolean accepts(long id,long version){
        return find(id).map(user->user.version()==version).orElse(false);
    }
    public SessionSnapshot lockCurrent(long id) {
        SessionSnapshot current = lock(id);
        var authentication = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !(authentication.getPrincipal() instanceof AuthenticatedUser actor)
                || actor.id() != id || actor.version() != current.version()) throw invalid();
        return current;
    }
    public static BadCredentialsException invalid(){return new BadCredentialsException("유효하지 않은 인증 정보입니다.");}
}
