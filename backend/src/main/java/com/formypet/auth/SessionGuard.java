package com.formypet.auth;

import lombok.RequiredArgsConstructor;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.stereotype.Component;
import java.util.Optional;

@Component
@RequiredArgsConstructor
public class SessionGuard {
    private final JdbcTemplate jdbc;
    public record Snapshot(long id,String email,String passwordHash,String source,long version){}
    private static final String SELECT="SELECT id,email,password_hash,registration_source,auth_version FROM users ";
    public Optional<Snapshot> find(String email){return read("WHERE email=? AND account_status='ACTIVE'",email,false);}
    public Optional<Snapshot> find(long id){return read("WHERE id=? AND account_status='ACTIVE'",id,false);}
    public Snapshot lock(String email){return read("WHERE email=? AND account_status='ACTIVE'",email,true).orElseThrow(SessionGuard::invalid);}
    public Snapshot lock(long id){return read("WHERE id=? AND account_status='ACTIVE'",id,true).orElseThrow(SessionGuard::invalid);}
    public boolean accepts(long id,long version){
        return find(id).map(user->user.version()==version).orElse(false);
    }
    public Snapshot lockCurrent(long id) {
        Snapshot current = lock(id);
        var authentication = org.springframework.security.core.context.SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !(authentication.getPrincipal() instanceof AuthenticatedUser actor)
                || actor.id() != id || actor.version() != current.version()) throw invalid();
        return current;
    }
    private Optional<Snapshot> read(String where,Object key,boolean lock){
        return jdbc.query(SELECT+where+(lock?" FOR UPDATE":""),(rs,n)->new Snapshot(
                rs.getLong("id"),rs.getString("email"),rs.getString("password_hash"),
                rs.getString("registration_source"),rs.getLong("auth_version")),key).stream().findFirst();
    }
    public static BadCredentialsException invalid(){return new BadCredentialsException("유효하지 않은 인증 정보입니다.");}
}
