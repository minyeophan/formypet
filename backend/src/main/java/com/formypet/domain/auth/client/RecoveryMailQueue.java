package com.formypet.domain.auth.client;

import com.formypet.domain.auth.config.RecoveryProperties;

import jakarta.annotation.PreDestroy;
import org.springframework.beans.factory.annotation.Qualifier;
import com.formypet.domain.auth.repository.jdbc.RecoveryCommands;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.*;
import org.slf4j.*;
import java.time.*;
import java.util.concurrent.*;

@Component
public class RecoveryMailQueue {
    private static final Logger log=LoggerFactory.getLogger(RecoveryMailQueue.class);
    private final ThreadPoolExecutor executor;
    private final RecoveryMailTransport transport;
    private final RecoveryCommands commands;
    private final Clock clock;
    public RecoveryMailQueue(RecoveryProperties properties,RecoveryMailTransport transport,RecoveryCommands commands,
                             @Qualifier("recoveryClock") Clock clock){
        this.transport=transport;this.commands=commands;this.clock=clock;
        executor=new ThreadPoolExecutor(1,1,0,TimeUnit.SECONDS,new ArrayBlockingQueue<>(properties.getQueueCapacity()),
                Thread.ofPlatform().daemon().name("recovery-mail-",0).factory(),new ThreadPoolExecutor.AbortPolicy());
    }
    public void codeAfterCommit(String id,String recipient,String code){
        afterCommit(id,()->{
            if(recipient==null)return;
            if(commands.isPendingCode(id,clock.instant()))transport.sendCode(recipient,code);
        });
    }
    public void changedAfterCommit(String id,String recipient){
        afterCommit(id,()->transport.sendChanged(recipient));
    }
    private void afterCommit(String id,MailTask task){
        Runnable submit=()->{
            try{executor.execute(()->{
                try{task.run();}catch(Exception e){log.warn("Recovery mail failed request={} kind={}",id,e.getClass().getSimpleName());}
            });}catch(RejectedExecutionException e){log.warn("Recovery mail queue unavailable request={}",id);}
        };
        if(TransactionSynchronizationManager.isSynchronizationActive()){
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization(){
                @Override public void afterCommit(){submit.run();}
            });
        }else submit.run();
    }
    @PreDestroy void close(){executor.shutdownNow();}
    @FunctionalInterface private interface MailTask{void run()throws Exception;}
}
