package com.formypet.auth.recovery;

import jakarta.annotation.PostConstruct;
import jakarta.mail.internet.InternetAddress;
import lombok.RequiredArgsConstructor;
import org.springframework.mail.javamail.*;
import org.springframework.stereotype.Component;

@Component
@RequiredArgsConstructor
public class RecoveryMailTransport {
    private final RecoveryProperties settings;
    private JavaMailSenderImpl sender;
    @PostConstruct void configure() {
        if(!settings.isEnabled())return;
        var mail=settings.getMail();
        try {
            address(mail.getFrom());
            if(mail.getUsername().isBlank()||mail.getPassword().isBlank()||mail.getHost().isBlank()
                    ||mail.getPort()<1||mail.getPort()>65535)throw new IllegalArgumentException();
        }catch(Exception e){throw new IllegalStateException("Password recovery SMTP configuration is invalid");}
        sender=new JavaMailSenderImpl();
        sender.setHost(mail.getHost());sender.setPort(mail.getPort());
        sender.setUsername(mail.getUsername());sender.setPassword(mail.getPassword());
        sender.setDefaultEncoding("UTF-8");
        var p=sender.getJavaMailProperties();
        p.setProperty("mail.smtp.auth","true");p.setProperty("mail.smtp.starttls.enable","true");
        p.setProperty("mail.smtp.starttls.required","true");p.setProperty("mail.smtp.ssl.checkserveridentity","true");
        p.setProperty("mail.smtp.connectiontimeout","10000");p.setProperty("mail.smtp.timeout","10000");
        p.setProperty("mail.smtp.writetimeout","10000");
    }
    public void sendCode(String email,String code)throws Exception {
        send(email,"[포마펫] 비밀번호 재설정 인증번호",
                "인증번호: "+code+"\n10분 안에 앱에 입력해 주세요. 재전송했다면 최신 번호를 사용해 주세요."
                +"\n본인이 요청하지 않았다면 이 메일을 무시하세요.");
    }
    public void sendChanged(String email)throws Exception {
        send(email,"[포마펫] 비밀번호가 변경되었습니다",
                "계정 비밀번호가 변경되어 기존 로그인 세션이 종료되었습니다.\n본인이 변경하지 않았다면 비밀번호 복구 후 고객지원에 문의해 주세요.");
    }
    private void send(String email,String subject,String body)throws Exception {
        if(sender==null)throw new IllegalStateException("Recovery mail disabled");
        address(email);
        var message=sender.createMimeMessage();
        var helper=new MimeMessageHelper(message,false,"UTF-8");
        helper.setFrom(settings.getMail().getFrom(),"포마펫");
        helper.setTo(email);helper.setSubject(subject);helper.setText(body,false);
        sender.send(message);
    }
    private static void address(String value)throws Exception {
        if(value==null||value.contains("\r")||value.contains("\n"))throw new IllegalArgumentException();
        var address=new InternetAddress(value,true);address.validate();
        if(!address.getAddress().equals(value)||!value.contains("@"))throw new IllegalArgumentException();
    }
}
