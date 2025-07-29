# Jenkins에서 빌드된 JAR 파일을 사용하는 Dockerfile

# JRE 17 이미지 사용 (빌드는 Jenkins에서 완료)
FROM openjdk:17-jdk

# 애플리케이션 실행을 위한 사용자 생성 (보안)
RUN groupadd -r spring && useradd -r -g spring spring

# 작업 디렉토리 설정
WORKDIR /app

# Jenkins에서 빌드된 JAR 파일 복사
COPY build/libs/*.jar app.jar

# 파일 소유권 변경
RUN chown spring:spring app.jar

# spring 사용자로 전환
USER spring

# 포트 노출 (Spring Boot 기본 포트)
EXPOSE 8080

# 애플리케이션 실행
ENTRYPOINT ["java", "-jar", "app.jar"]

