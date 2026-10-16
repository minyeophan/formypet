package com.formypet.domain.support.entity;

import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Map;

public record SupportMailMessage(String subject, String body, String replyTo) {
    public static SupportMailMessage from(SupportTicket ticket) {
        boolean inquiry = "INQUIRY".equals(ticket.getKind());
        String kind = inquiry ? "문의" : "신고";
        String subject = "[포마펫][" + kind + " #" + ticket.getId() + "] " + ticket.getTitle();
        String time = ticket.receivedAt().atZone(ZoneId.of("Asia/Seoul"))
                .format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
        String body = "접수번호: " + ticket.getId() + "\n접수시각(한국시간): " + time
                + "\n유형/사유: " + displayCategory(ticket.getCategory(), inquiry)
                + "\n제목: " + ticket.getTitle() + "\n내용:\n" + ticket.getContent()
                + (inquiry ? "\n답변 이메일: " + ticket.getReplyEmail()
                : "\n대상 게시글: " + ticket.getTargetPostId() + "\n접수 당시 내용:\n" + ticket.getTargetSnapshot());
        return new SupportMailMessage(subject, body, inquiry ? ticket.getReplyEmail() : null);
    }

    private static String displayCategory(String code, boolean inquiry) {
        Map<String, String> labels = inquiry ? Map.of(
                "ACCOUNT", "계정/로그인", "RECORD_ROUTINE", "기록/루틴", "COMMUNITY", "커뮤니티",
                "BUG", "오류 신고", "OTHER", "기타") : Map.of(
                "SPAM", "스팸/광고", "ABUSE", "욕설/비방", "INAPPROPRIATE", "부적절한 내용",
                "PRIVACY", "개인정보 침해", "OTHER", "기타");
        return labels.getOrDefault(code, code);
    }
}
