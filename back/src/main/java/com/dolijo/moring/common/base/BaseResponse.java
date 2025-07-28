package com.dolijo.moring.common.base;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;

import static com.dolijo.moring.common.base.BaseResponseStatus.SUCCESS;


public record BaseResponse<T>(HttpStatusCode httpStatus, Boolean isSuccess, String message, int code, T result) {
    /**
     * 필요값 : Http상태코드, 성공여부, 메시지, 에러코드, 결과값
     * 1. Return 객체가 필요한 경우 -> 성공
     * 2. Return 객체가 필요 없는 경우 -> 성공
     * 3. 요청에 실패한 경우
     */

    // 타입 명확히 지정한 static 메서드 (컨트롤러 전용)
    public static <T> BaseResponse<T> of(T result) {
        return new BaseResponse<>(HttpStatus.OK, true, SUCCESS.getMessage(), SUCCESS.getCode(), result);
    }

    public static BaseResponse<Void> ok() {
        return new BaseResponse<>(HttpStatus.OK, true, SUCCESS.getMessage(), SUCCESS.getCode(), null);
    }

    public static BaseResponse<Void> error(BaseResponseStatus status) {
        return new BaseResponse<>(status.getHttpStatusCode(), status.isSuccess(), status.getMessage(), status.getCode(), null);
    }

    // ✅ 예외 핸들러 등 기존 코드 호환 위한 생성자 유지
    public BaseResponse(T result) {
        this(HttpStatus.OK, true, SUCCESS.getMessage(), SUCCESS.getCode(), result);
    }

    public BaseResponse() {
        this(HttpStatus.OK, true, SUCCESS.getMessage(), SUCCESS.getCode(), null);
    }

    public BaseResponse(BaseResponseStatus status) {
        this(status.getHttpStatusCode(), status.isSuccess(), status.getMessage(), status.getCode(), null);
    }
}