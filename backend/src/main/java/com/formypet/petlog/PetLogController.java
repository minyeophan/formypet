package com.formypet.petlog;

import com.formypet.common.response.ApiResponse;
import com.formypet.common.idempotency.IdempotencyService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/pets/{petId}/pet-logs")
@RequiredArgsConstructor
public class PetLogController {
    private final PetLogService service;
    private final IdempotencyService idempotency;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<PetLogResponse> create(@AuthenticationPrincipal(expression="id") Long userId,
                                               @PathVariable Long petId,
                                               @RequestHeader(value="Idempotency-Key",required=false) String key,
                                               @RequestBody @Valid PetLogCreateRequest request) {
        return ApiResponse.of(idempotency.execute(userId,"pet-log-create",petId.toString(),key,request,List.of(),
                ()->service.create(userId,petId,request),PetLogResponse::id,id->{idempotency.requirePet(userId,petId);return service.get(userId,petId,id);}));
    }
    @GetMapping public ApiResponse<PetLogPageResponse> list(@AuthenticationPrincipal(expression="id") Long userId,@PathVariable Long petId,
            @RequestParam(required=false) Integer year,@RequestParam(required=false) Integer month,@RequestParam(defaultValue="20") int limit,@RequestParam(required=false) String cursor) {
        return ApiResponse.of(service.list(userId,petId,year,month,limit,cursor));
    }
    @GetMapping("/{id}") public ApiResponse<PetLogResponse> get(@AuthenticationPrincipal(expression="id") Long userId,@PathVariable Long petId,@PathVariable Long id){return ApiResponse.of(service.get(userId,petId,id));}
    @PutMapping("/{id}") public ApiResponse<PetLogResponse> update(@AuthenticationPrincipal(expression="id") Long userId,@PathVariable Long petId,@PathVariable Long id,
            @RequestHeader(value="Idempotency-Key",required=false) String key,@RequestBody @Valid PetLogUpdateRequest request){
        return ApiResponse.of(idempotency.executeVersioned(userId,"pet-log-update",petId+":"+id,key,request,List.of(),
                ()->service.update(userId,petId,id,request),PetLogResponse::id,PetLogResponse::version,
                (result,appliedVersion)->service.get(userId,petId,result).withAppliedVersion(appliedVersion)));
    }
    @DeleteMapping("/{id}") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@AuthenticationPrincipal(expression="id") Long userId,@PathVariable Long petId,@PathVariable Long id,
            @RequestParam long version,@RequestHeader(value="Idempotency-Key",required=false) String key){
        idempotency.execute(userId,"pet-log-delete",petId+":"+id,key,new DeleteRequest(version),List.of(),
                ()->{service.delete(userId,petId,id,version);return id;},Long::longValue,result->result);
    }
    @PutMapping("/preferences") public ApiResponse<Boolean> dismissExample(@AuthenticationPrincipal(expression="id") Long userId,@PathVariable Long petId,@RequestBody ExamplePreference request){
        if(!request.exampleDismissed()) throw new IllegalArgumentException("exampleDismissed must be true");
        return ApiResponse.of(service.dismissExample(userId,petId));
    }
    @GetMapping("/preferences") public ApiResponse<Boolean> examplePreference(@AuthenticationPrincipal(expression="id") Long userId,@PathVariable Long petId){return ApiResponse.of(service.exampleDismissed(userId,petId));}
    public record ExamplePreference(boolean exampleDismissed) {}
    public record DeleteRequest(long version) {}
}
