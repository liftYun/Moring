package com.dolijo.moring.common.base;


import lombok.AllArgsConstructor;
import lombok.Getter;
import org.springframework.http.HttpStatus;
import org.springframework.http.HttpStatusCode;

// https://www.iana.org/assignments/http-status-codes/http-status-codes.xhtml
// following http status code standard from above

@Getter
@AllArgsConstructor
public enum BaseResponseStatus {

    /**
     * 2XX: Success(성공)
     **/
    SUCCESS(HttpStatus.OK, true, 200, "요청에 성공하였습니다."),

    /**
     * 4XX: Client Error(클라이언트 에러)
     */
    DISALLOWED_ACTION(HttpStatus.BAD_REQUEST, false, 400, "올바르지 않은 행위 요청입니다."),
    WRONG_JWT_TOKEN(HttpStatus.UNAUTHORIZED, false, 401, "다시 로그인 해주세요"),
    NO_SIGN_IN(HttpStatus.UNAUTHORIZED, false, 401, "로그인을 먼저 진행해주세요"),
    NO_ACCESS_AUTHORITY(HttpStatus.FORBIDDEN, false, 403, "접근 권한이 없습니다"),
    NO_EXIST_MEMBER(HttpStatus.NOT_FOUND, false, 404, "요청하신 정보를 찾을 수 없습니다."),


    /**
     * 5XX: Server Error(서버 에러)
     */
    INTERNAL_SERVER_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, false, 500, "Internal server error"),
    SSE_SEND_FAIL(HttpStatus.INTERNAL_SERVER_ERROR, false, 503, "알림 전송에 실패하였습니다."),
    REDIS_ERROR(HttpStatus.INTERNAL_SERVER_ERROR, false, 500, "Internal Cache system failure"),

    /**
     * Service Related Errors
     */

    // token
    TOKEN_NOT_VALID(HttpStatus.UNAUTHORIZED, false, 403, "토큰이 유효하지 않습니다."),

    // Users
    DUPLICATED_USER(HttpStatus.CONFLICT, false, 409, "이미 가입된 멤버입니다."),
    FAILED_TO_LOGIN(HttpStatus.UNAUTHORIZED, false, 400, "아이디 또는 패스워드를 다시 확인하세요."),
    DUPLICATED_SOCIAL_USER(HttpStatus.CONFLICT, false, 409, "이미 소셜 연동된 계정입니다."),
    DUPLICATED_SOCIAL_PROVIDER_USER(HttpStatus.CONFLICT, false, 409, "계정에 동일한 플랫폼이 이미 연동되어있습니다"),
    NO_EXIST_USER(HttpStatus.NOT_FOUND, false, 404, "존재하지 않는 멤버 정보입니다."),
    PASSWORD_MATCH_FAILED(HttpStatus.BAD_REQUEST, false, 400, "패스워드를 다시 확인해주세요."),
    NO_SUPPORTED_PROVIDER(HttpStatus.BAD_REQUEST, false, 400, "지원하지 않는 플랫폼입니다"),
    DUPLICATED_NICKNAME(HttpStatus.CONFLICT, false, 409, "이미 사용중인 닉네임입니다."),
    SAME_NICKNAME(HttpStatus.CONFLICT, false, 409, "현재 사용중인 닉네임입니다."),
    INVALID_EMAIL_ADDRESS(HttpStatus.BAD_REQUEST, false, 400, "이메일을 다시 확인해주세요."),


    /**
     * Notification
     */

    /**
     * Car
     */
    ALREADY_REGISTERED_CAR(HttpStatus.CONFLICT, false, 409, "이미 등록된 차량입니다."),
    NO_EXIST_CAR(HttpStatus.NOT_FOUND, false, 404, "존재하지 않는 차량입니다.");


    private final HttpStatusCode httpStatusCode;
    private final boolean isSuccess;
    private final int code;
    private final String message;

}