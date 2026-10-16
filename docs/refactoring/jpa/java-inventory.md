# Java 구조 및 DB 접근 목록

검사 시점: refactor/jpa-global 구현 완료 후, 최종 PR 검증 전. 런타임 완료 증거는 12-global.md 및 progress.md를 따른다.

프로덕션 Java: 386개. Application 진입점을 제외하고 domain 또는 global 아래에 있다.

## 저장소 SQL 유지 이유

- 조회 projection/커서/통계: 기존 API 정렬, NULL, 시간 및 페이지 경계를 보존한다.
- current read 및 refresh: 사용자/리소스 잠금 이후 JPA 캐시와 이전 DB snapshot보다 최신 값을 읽는다.
- 원자적 upsert/카운터/쿼터: 중복 방지와 동시 변경 수치 및 제한을 보존한다.
- cleanup/outbox/웹훅/계정 삭제: lease, 재시도, 일괄 변경 및 기존 잠금 순서를 보존한다.
- 세부 유지 사유와 회귀 테스트는 01-wallet.md부터 12-global.md 및 각 repository 인접 tests에 기록되어 있다.

## 직접 DB 접근 또는 명시적 쿼리가 있는 저장소

- com/formypet/domain/auth/repository/jdbc/KakaoSignupIntentRepository.java
- com/formypet/domain/auth/repository/jdbc/OAuthLifecycleLockRepository.java
- com/formypet/domain/auth/repository/jdbc/RecoveryCommands.java
- com/formypet/domain/auth/repository/jdbc/RecoveryLimitRepository.java
- com/formypet/domain/auth/repository/jdbc/RefreshTokenCurrentReadRepository.java
- com/formypet/domain/auth/repository/jdbc/SessionSnapshotRepository.java
- com/formypet/domain/auth/repository/PasswordResetChallengeCurrentReadsImpl.java
- com/formypet/domain/community/repository/jdbc/PostCounterRepository.java
- com/formypet/domain/community/repository/jdbc/ReactionInsertRepository.java
- com/formypet/domain/community/repository/PostCommentRepository.java
- com/formypet/domain/community/repository/PostRelationsRepository.java
- com/formypet/domain/community/repository/query/CommentProjectionRepository.java
- com/formypet/domain/community/repository/query/PostProjectionRepository.java
- com/formypet/domain/media/repository/jdbc/MediaAttachmentRepository.java
- com/formypet/domain/media/repository/jdbc/MediaQuotaRepository.java
- com/formypet/domain/media/repository/jdbc/MediaWorkRepository.java
- com/formypet/domain/media/repository/MediaResourceRepository.java
- com/formypet/domain/notification/repository/DeviceTokenRepository.java
- com/formypet/domain/notification/repository/jdbc/NotificationCommands.java
- com/formypet/domain/notification/repository/NotificationRepository.java
- com/formypet/domain/notification/repository/query/NotificationFeedImpl.java
- com/formypet/domain/notification/repository/query/ReminderCandidateRepository.java
- com/formypet/domain/pet/repository/query/PetProfileImageQueryRepository.java
- com/formypet/domain/petlog/repository/PetLogCurrentReadsImpl.java
- com/formypet/domain/petlog/repository/PetLogPhotoRepository.java
- com/formypet/domain/petlog/repository/PetLogPreferenceRepository.java
- com/formypet/domain/petlog/repository/PetLogQueryRepository.java
- com/formypet/domain/policy/repository/jdbc/PolicyDatabaseAccess.java
- com/formypet/domain/policy/repository/PolicyConsentRepository.java
- com/formypet/domain/policy/repository/PolicyPublicationRepository.java
- com/formypet/domain/policy/repository/PolicyRuntimeRepository.java
- com/formypet/domain/record/repository/ActivityRecordQueriesImpl.java
- com/formypet/domain/record/repository/RecordDetailRepository.java
- com/formypet/domain/record/repository/RecordMediaQueryRepository.java
- com/formypet/domain/routine/repository/CareScheduleRefreshImpl.java
- com/formypet/domain/routine/repository/CareScheduleRepository.java
- com/formypet/domain/routine/repository/query/CareSchedulePetAccessRepository.java
- com/formypet/domain/routine/repository/query/RoutineActivityTypeRepository.java
- com/formypet/domain/routine/repository/RoutineCompletionAtomicImpl.java
- com/formypet/domain/support/repository/jdbc/SupportOutboxCommands.java
- com/formypet/domain/support/repository/query/SupportAccessRepository.java
- com/formypet/domain/user/repository/jdbc/AccountDeletionCommands.java
- com/formypet/domain/user/repository/jdbc/KakaoDeletionJobRepository.java
- com/formypet/domain/user/repository/jdbc/KakaoWebhookRepository.java
- com/formypet/domain/user/repository/UserBlockRepository.java
- com/formypet/domain/wallet/repository/query/WalletExpenseQueryRepository.java
- com/formypet/domain/wallet/repository/query/WalletPetAccessRepository.java
- com/formypet/domain/wallet/repository/WalletExpenseRefreshImpl.java
- com/formypet/global/idempotency/repository/IdempotencyRepository.java
- com/formypet/global/idempotency/repository/ReplayTargetRepository.java
- com/formypet/global/ratelimit/repository/RequestRateLimitRepository.java

## 전체 파일

```text
com/formypet/domain/auth/client/KakaoUserClient.java
com/formypet/domain/auth/client/KakaoUserInfo.java
com/formypet/domain/auth/client/package-info.java
com/formypet/domain/auth/client/RecoveryMailQueue.java
com/formypet/domain/auth/client/RecoveryMailTransport.java
com/formypet/domain/auth/client/RestClientKakaoUserClient.java
com/formypet/domain/auth/config/RecoveryConfiguration.java
com/formypet/domain/auth/config/RecoveryProperties.java
com/formypet/domain/auth/controller/AuthController.java
com/formypet/domain/auth/controller/RecoveryController.java
com/formypet/domain/auth/dto/request/CancelSignupRequest.java
com/formypet/domain/auth/dto/request/KakaoLoginRequest.java
com/formypet/domain/auth/dto/request/LoginRequest.java
com/formypet/domain/auth/dto/request/RefreshRequest.java
com/formypet/domain/auth/dto/request/RegisterRequest.java
com/formypet/domain/auth/dto/request/ResetConfirmRequest.java
com/formypet/domain/auth/dto/request/ResetRequest.java
com/formypet/domain/auth/dto/request/ResetVerifyRequest.java
com/formypet/domain/auth/dto/response/ResetChallengeResponse.java
com/formypet/domain/auth/dto/response/ResetVerifiedResponse.java
com/formypet/domain/auth/dto/response/SignupCancellationResponse.java
com/formypet/domain/auth/dto/response/TokenResponse.java
com/formypet/domain/auth/entity/OAuthAccount.java
com/formypet/domain/auth/entity/PasswordResetChallenge.java
com/formypet/domain/auth/entity/RefreshToken.java
com/formypet/domain/auth/entity/SessionSnapshot.java
com/formypet/domain/auth/exception/OAuthLoginConflictException.java
com/formypet/domain/auth/exception/RecoveryErrors.java
com/formypet/domain/auth/repository/jdbc/KakaoSignupIntentRepository.java
com/formypet/domain/auth/repository/jdbc/OAuthLifecycleLockRepository.java
com/formypet/domain/auth/repository/jdbc/RecoveryCommands.java
com/formypet/domain/auth/repository/jdbc/RecoveryLimitRepository.java
com/formypet/domain/auth/repository/jdbc/RefreshTokenCurrentReadRepository.java
com/formypet/domain/auth/repository/jdbc/SessionSnapshotRepository.java
com/formypet/domain/auth/repository/OAuthAccountRepository.java
com/formypet/domain/auth/repository/PasswordResetChallengeCurrentReads.java
com/formypet/domain/auth/repository/PasswordResetChallengeCurrentReadsImpl.java
com/formypet/domain/auth/repository/PasswordResetChallengeRepository.java
com/formypet/domain/auth/repository/RefreshTokenRepository.java
com/formypet/domain/auth/scheduling/KakaoSignupCleanup.java
com/formypet/domain/auth/scheduling/RecoveryCleanup.java
com/formypet/domain/auth/security/AuthenticatedUser.java
com/formypet/domain/auth/security/JwtAuthFilter.java
com/formypet/domain/auth/security/JwtService.java
com/formypet/domain/auth/security/OAuthLifecycleGuard.java
com/formypet/domain/auth/security/RecoveryCrypto.java
com/formypet/domain/auth/security/RecoveryRateLimiter.java
com/formypet/domain/auth/security/SessionGuard.java
com/formypet/domain/auth/service/AuthService.java
com/formypet/domain/auth/service/impl/AuthServiceImpl.java
com/formypet/domain/auth/service/impl/KakaoSignupIntentsImpl.java
com/formypet/domain/auth/service/impl/OAuthSignupServiceImpl.java
com/formypet/domain/auth/service/impl/RecoveryServiceImpl.java
com/formypet/domain/auth/service/impl/RecoveryTransactionsImpl.java
com/formypet/domain/auth/service/KakaoSignupIntents.java
com/formypet/domain/auth/service/OAuthSignupService.java
com/formypet/domain/auth/service/RecoveryService.java
com/formypet/domain/auth/service/RecoveryTransactions.java
com/formypet/domain/auth/validation/NewPassword.java
com/formypet/domain/auth/validation/NewPasswordValidator.java
com/formypet/domain/community/controller/CommunityController.java
com/formypet/domain/community/controller/MyActivityController.java
com/formypet/domain/community/dto/PostCommentReportReason.java
com/formypet/domain/community/dto/request/PostCommentCreateRequest.java
com/formypet/domain/community/dto/request/PostCommentReportRequest.java
com/formypet/domain/community/dto/request/PostCommentUpdateRequest.java
com/formypet/domain/community/dto/request/PostCreateRequest.java
com/formypet/domain/community/dto/request/PostUpdateRequest.java
com/formypet/domain/community/dto/response/MyActivityResponse.java
com/formypet/domain/community/dto/response/PostCommentFeedResponse.java
com/formypet/domain/community/dto/response/PostCommentReportResponse.java
com/formypet/domain/community/dto/response/PostCommentResponse.java
com/formypet/domain/community/dto/response/PostFeedResponse.java
com/formypet/domain/community/dto/response/PostLikeResponse.java
com/formypet/domain/community/dto/response/PostResponse.java
com/formypet/domain/community/entity/Post.java
com/formypet/domain/community/entity/PostComment.java
com/formypet/domain/community/entity/PostCommentReport.java
com/formypet/domain/community/entity/PostLike.java
com/formypet/domain/community/entity/PostMedia.java
com/formypet/domain/community/entity/PostPoll.java
com/formypet/domain/community/entity/PostPollOption.java
com/formypet/domain/community/entity/PostPollVote.java
com/formypet/domain/community/repository/jdbc/PostCounterRepository.java
com/formypet/domain/community/repository/jdbc/ReactionInsertRepository.java
com/formypet/domain/community/repository/PostCommentReportRepository.java
com/formypet/domain/community/repository/PostCommentRepository.java
com/formypet/domain/community/repository/PostRelationsRepository.java
com/formypet/domain/community/repository/PostRepository.java
com/formypet/domain/community/repository/query/CommentProjectionRepository.java
com/formypet/domain/community/repository/query/PostProjectionRepository.java
com/formypet/domain/community/service/ActivityService.java
com/formypet/domain/community/service/CommentService.java
com/formypet/domain/community/service/CommunityAccess.java
com/formypet/domain/community/service/CommunityService.java
com/formypet/domain/community/service/impl/ActivityServiceImpl.java
com/formypet/domain/community/service/impl/CommentServiceImpl.java
com/formypet/domain/community/service/impl/CommunityServiceImpl.java
com/formypet/domain/community/service/impl/PostServiceImpl.java
com/formypet/domain/community/service/impl/ReactionServiceImpl.java
com/formypet/domain/community/service/PostService.java
com/formypet/domain/community/service/ReactionService.java
com/formypet/domain/media/controller/MediaController.java
com/formypet/domain/media/dto/response/MediaResponse.java
com/formypet/domain/media/entity/MediaResource.java
com/formypet/domain/media/repository/jdbc/MediaAttachmentRepository.java
com/formypet/domain/media/repository/jdbc/MediaQuotaRepository.java
com/formypet/domain/media/repository/jdbc/MediaWorkRepository.java
com/formypet/domain/media/repository/MediaResourceRepository.java
com/formypet/domain/media/repository/query/MediaFile.java
com/formypet/domain/media/repository/query/MediaLocation.java
com/formypet/domain/media/scheduling/MediaCleanupRunner.java
com/formypet/domain/media/service/impl/MediaDeletionServiceImpl.java
com/formypet/domain/media/service/impl/MediaQueryServiceImpl.java
com/formypet/domain/media/service/impl/MediaServiceImpl.java
com/formypet/domain/media/service/impl/MediaStorageAttemptsImpl.java
com/formypet/domain/media/service/impl/MediaUploadServiceImpl.java
com/formypet/domain/media/service/impl/OrphanMediaCleanupImpl.java
com/formypet/domain/media/service/MediaDeletionService.java
com/formypet/domain/media/service/MediaQueryService.java
com/formypet/domain/media/service/MediaService.java
com/formypet/domain/media/service/MediaStorageAttempts.java
com/formypet/domain/media/service/MediaUploadService.java
com/formypet/domain/media/service/OrphanMediaCleanup.java
com/formypet/domain/media/storage/LoadedMedia.java
com/formypet/domain/media/storage/LocalMediaStorage.java
com/formypet/domain/media/storage/MediaImageDimensions.java
com/formypet/domain/media/storage/MediaRollbackCleanup.java
com/formypet/domain/media/storage/MediaStorage.java
com/formypet/domain/media/storage/R2MediaStorage.java
com/formypet/domain/media/storage/R2MediaStorageConfiguration.java
com/formypet/domain/media/storage/R2StorageProperties.java
com/formypet/domain/media/storage/StoredMedia.java
com/formypet/domain/media/validation/MediaFileValidation.java
com/formypet/domain/media/validation/MediaUploadValidation.java
com/formypet/domain/notification/client/FirebasePushSender.java
com/formypet/domain/notification/client/PushSender.java
com/formypet/domain/notification/client/PushSendResult.java
com/formypet/domain/notification/config/NotificationConfiguration.java
com/formypet/domain/notification/config/NotificationProperties.java
com/formypet/domain/notification/controller/NotificationController.java
com/formypet/domain/notification/dto/request/DeviceTokenRequest.java
com/formypet/domain/notification/dto/request/NotificationSettingsRequest.java
com/formypet/domain/notification/dto/response/NotificationFeedResponse.java
com/formypet/domain/notification/dto/response/NotificationResponse.java
com/formypet/domain/notification/dto/response/NotificationSettingsResponse.java
com/formypet/domain/notification/entity/DeviceToken.java
com/formypet/domain/notification/entity/Notification.java
com/formypet/domain/notification/entity/NotificationType.java
com/formypet/domain/notification/entity/ReminderSchedule.java
com/formypet/domain/notification/repository/DeviceTokenRepository.java
com/formypet/domain/notification/repository/jdbc/NotificationCommands.java
com/formypet/domain/notification/repository/NotificationRepository.java
com/formypet/domain/notification/repository/query/CareReminderCandidate.java
com/formypet/domain/notification/repository/query/DeviceTokenSnapshot.java
com/formypet/domain/notification/repository/query/NotificationFeed.java
com/formypet/domain/notification/repository/query/NotificationFeedImpl.java
com/formypet/domain/notification/repository/query/NotificationRow.java
com/formypet/domain/notification/repository/query/NotificationVisibility.java
com/formypet/domain/notification/repository/query/ReminderCandidateRepository.java
com/formypet/domain/notification/repository/query/RoutineReminderCandidate.java
com/formypet/domain/notification/scheduling/CareScheduleReminderJob.java
com/formypet/domain/notification/scheduling/NotificationCleanupJob.java
com/formypet/domain/notification/scheduling/RoutineReminderJob.java
com/formypet/domain/notification/service/CareScheduleReminderService.java
com/formypet/domain/notification/service/DeviceTokenService.java
com/formypet/domain/notification/service/impl/CareScheduleReminderServiceImpl.java
com/formypet/domain/notification/service/impl/DeviceTokenServiceImpl.java
com/formypet/domain/notification/service/impl/NotificationQueryServiceImpl.java
com/formypet/domain/notification/service/impl/NotificationReminderServiceImpl.java
com/formypet/domain/notification/service/impl/NotificationServiceImpl.java
com/formypet/domain/notification/service/impl/NotificationSettingsServiceImpl.java
com/formypet/domain/notification/service/impl/ReminderPushDispatcherImpl.java
com/formypet/domain/notification/service/impl/RoutineReminderServiceImpl.java
com/formypet/domain/notification/service/NotificationQueryService.java
com/formypet/domain/notification/service/NotificationReminderService.java
com/formypet/domain/notification/service/NotificationService.java
com/formypet/domain/notification/service/NotificationSettingsService.java
com/formypet/domain/notification/service/ReminderPushDispatcher.java
com/formypet/domain/notification/service/RoutineReminderService.java
com/formypet/domain/pet/controller/PetController.java
com/formypet/domain/pet/dto/request/PetCreateRequest.java
com/formypet/domain/pet/dto/request/PetUpdateRequest.java
com/formypet/domain/pet/dto/request/StrictBigDecimalDeserializer.java
com/formypet/domain/pet/dto/response/PetResponse.java
com/formypet/domain/pet/entity/Gender.java
com/formypet/domain/pet/entity/Pet.java
com/formypet/domain/pet/repository/PetRepository.java
com/formypet/domain/pet/repository/query/PetProfileImageQueryRepository.java
com/formypet/domain/pet/service/impl/PetServiceImpl.java
com/formypet/domain/pet/service/PetService.java
com/formypet/domain/petlog/controller/PetLogController.java
com/formypet/domain/petlog/dto/request/DeleteRequest.java
com/formypet/domain/petlog/dto/request/ExamplePreference.java
com/formypet/domain/petlog/dto/request/PetLogCreateRequest.java
com/formypet/domain/petlog/dto/request/PetLogUpdateRequest.java
com/formypet/domain/petlog/dto/response/PetLogPageResponse.java
com/formypet/domain/petlog/dto/response/PetLogPhotoResponse.java
com/formypet/domain/petlog/dto/response/PetLogResponse.java
com/formypet/domain/petlog/entity/PetLog.java
com/formypet/domain/petlog/repository/PetLogCurrentReads.java
com/formypet/domain/petlog/repository/PetLogCurrentReadsImpl.java
com/formypet/domain/petlog/repository/PetLogPhotoRepository.java
com/formypet/domain/petlog/repository/PetLogPreferenceRepository.java
com/formypet/domain/petlog/repository/PetLogQueryRepository.java
com/formypet/domain/petlog/repository/PetLogRepository.java
com/formypet/domain/petlog/scheduling/PetLogDraftCleanupJob.java
com/formypet/domain/petlog/service/impl/PetLogServiceImpl.java
com/formypet/domain/petlog/service/PetLogService.java
com/formypet/domain/policy/config/PolicyCatalogLoader.java
com/formypet/domain/policy/config/PolicyGate.java
com/formypet/domain/policy/controller/PolicyConsentController.java
com/formypet/domain/policy/controller/PublicPolicyController.java
com/formypet/domain/policy/dto/request/PolicyAcceptance.java
com/formypet/domain/policy/dto/response/PolicyCatalogResponse.java
com/formypet/domain/policy/dto/response/PolicyConsentHistoryResponse.java
com/formypet/domain/policy/dto/response/PolicyConsentStatusResponse.java
com/formypet/domain/policy/dto/response/PolicyDocumentResponse.java
com/formypet/domain/policy/entity/PolicyConsent.java
com/formypet/domain/policy/entity/PolicyPublication.java
com/formypet/domain/policy/entity/PolicyPublicationId.java
com/formypet/domain/policy/entity/PolicyRuntime.java
com/formypet/domain/policy/repository/jdbc/PolicyDatabaseAccess.java
com/formypet/domain/policy/repository/PolicyConsentRepository.java
com/formypet/domain/policy/repository/PolicyPublicationRepository.java
com/formypet/domain/policy/repository/PolicyRuntimeRepository.java
com/formypet/domain/policy/service/impl/PolicyCatalogImpl.java
com/formypet/domain/policy/service/impl/PolicyConsentServiceImpl.java
com/formypet/domain/policy/service/impl/PolicyPublicationRegistryImpl.java
com/formypet/domain/policy/service/PolicyCatalog.java
com/formypet/domain/policy/service/PolicyConsentService.java
com/formypet/domain/policy/service/PolicyPublicationRegistry.java
com/formypet/domain/record/controller/ActivityRecordController.java
com/formypet/domain/record/dto/request/ActivityRecordCreateRequest.java
com/formypet/domain/record/dto/request/ActivityRecordUpdateRequest.java
com/formypet/domain/record/dto/response/ActivityRecordResponse.java
com/formypet/domain/record/entity/ActivityRecord.java
com/formypet/domain/record/entity/detail/DetailValues.java
com/formypet/domain/record/entity/detail/MealRecordDetail.java
com/formypet/domain/record/entity/detail/MedicineRecordDetail.java
com/formypet/domain/record/entity/detail/PoopRecordDetail.java
com/formypet/domain/record/entity/detail/RecordDetail.java
com/formypet/domain/record/entity/detail/VetRecordDetail.java
com/formypet/domain/record/entity/detail/WalkRecordDetail.java
com/formypet/domain/record/entity/detail/WaterRecordDetail.java
com/formypet/domain/record/entity/detail/WeightRecordDetail.java
com/formypet/domain/record/repository/ActivityRecordQueries.java
com/formypet/domain/record/repository/ActivityRecordQueriesImpl.java
com/formypet/domain/record/repository/ActivityRecordRepository.java
com/formypet/domain/record/repository/RecordDetailRepository.java
com/formypet/domain/record/repository/RecordMediaQueryRepository.java
com/formypet/domain/record/service/ActivityRecordService.java
com/formypet/domain/record/service/impl/ActivityRecordServiceImpl.java
com/formypet/domain/routine/controller/CareScheduleController.java
com/formypet/domain/routine/controller/RoutineController.java
com/formypet/domain/routine/dto/request/CareScheduleRequest.java
com/formypet/domain/routine/dto/request/RoutineCompletionRequest.java
com/formypet/domain/routine/dto/request/RoutineCreateRequest.java
com/formypet/domain/routine/dto/request/RoutineUpdateRequest.java
com/formypet/domain/routine/dto/response/CareScheduleResponse.java
com/formypet/domain/routine/dto/response/RoutineCompletionResponse.java
com/formypet/domain/routine/dto/response/RoutineResponse.java
com/formypet/domain/routine/dto/response/TodayRoutineResponse.java
com/formypet/domain/routine/entity/CareSchedule.java
com/formypet/domain/routine/entity/Routine.java
com/formypet/domain/routine/entity/RoutineCompletion.java
com/formypet/domain/routine/repository/CareScheduleRefresh.java
com/formypet/domain/routine/repository/CareScheduleRefreshImpl.java
com/formypet/domain/routine/repository/CareScheduleRepository.java
com/formypet/domain/routine/repository/query/CareSchedulePetAccessRepository.java
com/formypet/domain/routine/repository/query/RoutineActivityTypeRepository.java
com/formypet/domain/routine/repository/RoutineCompletionAtomic.java
com/formypet/domain/routine/repository/RoutineCompletionAtomicImpl.java
com/formypet/domain/routine/repository/RoutineCompletionRepository.java
com/formypet/domain/routine/repository/RoutineRepository.java
com/formypet/domain/routine/service/CareScheduleService.java
com/formypet/domain/routine/service/impl/CareScheduleServiceImpl.java
com/formypet/domain/routine/service/impl/RoutineServiceImpl.java
com/formypet/domain/routine/service/RoutineService.java
com/formypet/domain/support/client/SupportMailTransport.java
com/formypet/domain/support/config/SupportMailProperties.java
com/formypet/domain/support/controller/SupportController.java
com/formypet/domain/support/dto/request/InquiryRequest.java
com/formypet/domain/support/dto/request/ReportRequest.java
com/formypet/domain/support/dto/response/SupportReceipt.java
com/formypet/domain/support/entity/MailRetryPolicy.java
com/formypet/domain/support/entity/SupportMailMessage.java
com/formypet/domain/support/entity/SupportMailOutbox.java
com/formypet/domain/support/entity/SupportTicket.java
com/formypet/domain/support/repository/jdbc/SupportOutboxCommands.java
com/formypet/domain/support/repository/query/SupportAccessRepository.java
com/formypet/domain/support/repository/query/SupportPostSnapshot.java
com/formypet/domain/support/repository/SupportMailOutboxRepository.java
com/formypet/domain/support/repository/SupportTicketRepository.java
com/formypet/domain/support/scheduling/SupportMailScheduler.java
com/formypet/domain/support/service/impl/SupportMailWorkerImpl.java
com/formypet/domain/support/service/impl/SupportServiceImpl.java
com/formypet/domain/support/service/SupportMailWorker.java
com/formypet/domain/support/service/SupportService.java
com/formypet/domain/user/client/KakaoAccountUnlinker.java
com/formypet/domain/user/client/RestKakaoAccountUnlinker.java
com/formypet/domain/user/controller/AccountDeletionController.java
com/formypet/domain/user/controller/KakaoUnlinkWebhookController.java
com/formypet/domain/user/controller/PublicAccountDeletionController.java
com/formypet/domain/user/controller/UserBlockController.java
com/formypet/domain/user/controller/UserProfileController.java
com/formypet/domain/user/controller/UserProfileImageController.java
com/formypet/domain/user/dto/request/AccountDeletionRequest.java
com/formypet/domain/user/dto/request/PublicAccountDeletionRequest.java
com/formypet/domain/user/dto/request/UserProfileUpdateRequest.java
com/formypet/domain/user/dto/response/AccountDeletionReceipt.java
com/formypet/domain/user/dto/response/BlockedUser.java
com/formypet/domain/user/dto/response/BlockList.java
com/formypet/domain/user/dto/response/PublicAccountDeletionReceipt.java
com/formypet/domain/user/dto/response/UserProfileResponse.java
com/formypet/domain/user/entity/AccountCleanupRetry.java
com/formypet/domain/user/entity/User.java
com/formypet/domain/user/entity/UserBlock.java
com/formypet/domain/user/entity/UserBlockId.java
com/formypet/domain/user/repository/jdbc/AccountDeletionCommands.java
com/formypet/domain/user/repository/jdbc/KakaoDeletionJobRepository.java
com/formypet/domain/user/repository/jdbc/KakaoWebhookRepository.java
com/formypet/domain/user/repository/query/BlockedUserRow.java
com/formypet/domain/user/repository/UserBlockRepository.java
com/formypet/domain/user/repository/UserRepository.java
com/formypet/domain/user/scheduling/KakaoAccountDeletionWorkerScheduler.java
com/formypet/domain/user/scheduling/KakaoUnlinkWebhookWorkerScheduler.java
com/formypet/domain/user/security/KakaoUnlinkWebhookAuthorizer.java
com/formypet/domain/user/service/AccountDeletionService.java
com/formypet/domain/user/service/AccountDeletionTransaction.java
com/formypet/domain/user/service/impl/AccountDeletionServiceImpl.java
com/formypet/domain/user/service/impl/AccountDeletionTransactionImpl.java
com/formypet/domain/user/service/impl/KakaoAccountDeletionWorkerImpl.java
com/formypet/domain/user/service/impl/KakaoUnlinkWebhookEventProcessorImpl.java
com/formypet/domain/user/service/impl/KakaoUnlinkWebhookEventQueueImpl.java
com/formypet/domain/user/service/impl/KakaoUnlinkWebhookServiceImpl.java
com/formypet/domain/user/service/impl/KakaoUnlinkWebhookWorkerImpl.java
com/formypet/domain/user/service/impl/PublicAccountDeletionRequestServiceImpl.java
com/formypet/domain/user/service/impl/UserBlockServiceImpl.java
com/formypet/domain/user/service/impl/UserProfileServiceImpl.java
com/formypet/domain/user/service/KakaoAccountDeletionWorker.java
com/formypet/domain/user/service/KakaoUnlinkWebhookEventProcessor.java
com/formypet/domain/user/service/KakaoUnlinkWebhookEventQueue.java
com/formypet/domain/user/service/KakaoUnlinkWebhookService.java
com/formypet/domain/user/service/KakaoUnlinkWebhookWorker.java
com/formypet/domain/user/service/PublicAccountDeletionRequestService.java
com/formypet/domain/user/service/UserBlockService.java
com/formypet/domain/user/service/UserProfileService.java
com/formypet/domain/wallet/controller/WalletExpenseController.java
com/formypet/domain/wallet/dto/request/WalletExpenseCreateRequest.java
com/formypet/domain/wallet/dto/request/WalletExpenseUpdateRequest.java
com/formypet/domain/wallet/dto/response/WalletExpenseCategorySummary.java
com/formypet/domain/wallet/dto/response/WalletExpenseListResponse.java
com/formypet/domain/wallet/dto/response/WalletExpenseResponse.java
com/formypet/domain/wallet/dto/response/WalletExpenseSummaryResponse.java
com/formypet/domain/wallet/entity/WalletExpense.java
com/formypet/domain/wallet/repository/query/WalletExpenseQueryRepository.java
com/formypet/domain/wallet/repository/query/WalletPetAccessRepository.java
com/formypet/domain/wallet/repository/WalletExpenseRefresh.java
com/formypet/domain/wallet/repository/WalletExpenseRefreshImpl.java
com/formypet/domain/wallet/repository/WalletExpenseRepository.java
com/formypet/domain/wallet/service/impl/WalletExpenseServiceImpl.java
com/formypet/domain/wallet/service/WalletExpenseService.java
com/formypet/FormypetApplication.java
com/formypet/global/config/FirebaseConfiguration.java
com/formypet/global/config/MultipartLimitsConfiguration.java
com/formypet/global/config/OpenApiConfiguration.java
com/formypet/global/config/OpenApiOperationCustomizer.java
com/formypet/global/config/SecurityConfig.java
com/formypet/global/exception/ApiException.java
com/formypet/global/exception/ForbiddenException.java
com/formypet/global/exception/GlobalExceptionHandler.java
com/formypet/global/exception/InvalidInputException.java
com/formypet/global/exception/NotFoundException.java
com/formypet/global/health/HealthController.java
com/formypet/global/idempotency/IdempotencyService.java
com/formypet/global/idempotency/repository/IdempotencyRepository.java
com/formypet/global/idempotency/repository/ReplayTargetRepository.java
com/formypet/global/monitoring/MonitoringMetricsConfiguration.java
com/formypet/global/monitoring/MonitoringSecurityConfiguration.java
com/formypet/global/ratelimit/ClientAddressResolver.java
com/formypet/global/ratelimit/repository/RequestRateLimitRepository.java
com/formypet/global/ratelimit/RequestRateLimiter.java
com/formypet/global/ratelimit/RequestRateLimitProperties.java
com/formypet/global/response/ApiResponse.java
com/formypet/global/time/UtcTime.java
```
