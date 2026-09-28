package com.formypet.notification;

import org.junit.jupiter.api.Test;
import static org.assertj.core.api.Assertions.assertThat;

class PushPrivacyTest {
    @Test void remoteNotificationContainsOnlyGenericText() {
        var notification = FirebasePushSender.privateNotification();
        assertThat(notification).extracting("title", "body")
                .containsExactly("포마펫", "확인할 알림이 있어요. 앱에서 확인해 주세요.");
    }
}
