package com.formypet.policy;

import com.formypet.common.exception.ApiException;
import com.formypet.common.response.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.util.HtmlUtils;

@RestController
@RequiredArgsConstructor
public class PublicPolicyController {
    private static final MediaType HTML = new MediaType("text", "html", java.nio.charset.StandardCharsets.UTF_8);
    private final PolicyCatalog policies;
    @GetMapping("/api/v1/public/policies")
    public ApiResponse<PolicyCatalog.Status> list() { return ApiResponse.of(policies.status()); }
    @GetMapping("/api/v1/public/policies/{type}/{version}")
    public ApiResponse<PolicyCatalog.Document> document(@PathVariable String type, @PathVariable String version) {
        return ApiResponse.of(policies.version(type, version));
    }
    @GetMapping(value = {"/privacy", "/terms"}, produces = "text/html;charset=UTF-8")
    public ResponseEntity<String> current(jakarta.servlet.http.HttpServletRequest request) {
        try { return render(policies.current(request.getRequestURI().endsWith("/privacy") ? "privacy" : "terms")); }
        catch (ApiException unavailable) {
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).contentType(HTML)
                    .body(page("정책 게시 준비 중", "<p>운영 정보와 정책 전문을 확인 중입니다. 아직 최종 게시된 정책이 아닙니다.</p>"));
        }
    }
    @GetMapping(value = "/policies/{type}/{version}", produces = "text/html;charset=UTF-8")
    public ResponseEntity<String> archived(@PathVariable String type, @PathVariable String version) {
        return render(policies.version(type, version));
    }
    private ResponseEntity<String> render(PolicyCatalog.Document doc) {
        String details = "<p>버전 " + escape(doc.version()) + " · 게시일 " + doc.publishedAt()
                + " · 시행일 " + doc.effectiveAt() + "</p><article style='white-space:pre-wrap'>" + escape(doc.body()) + "</article>";
        return ResponseEntity.ok().contentType(HTML).body(page(doc.title(), details));
    }
    private static String page(String title, String body) {
        return "<!doctype html><html lang='ko'><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>"
                + "<title>" + escape(title) + " · 포마펫</title><body style='max-width:800px;margin:32px auto;padding:0 20px;font-family:sans-serif;line-height:1.7'>"
                + "<nav><a href='/terms'>이용약관</a> · <a href='/privacy'>개인정보 처리방침</a> · <a href='/account-deletion.html'>계정 삭제 요청</a></nav>"
                + "<main><h1>" + escape(title) + "</h1>" + body + "</main></body></html>";
    }
    private static String escape(String text) { return HtmlUtils.htmlEscape(text); }
}
