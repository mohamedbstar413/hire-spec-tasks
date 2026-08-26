FROM eclipse-temurin:21-jdk

WORKDIR /app

COPY exam/pom.xml .
RUN mvn dependency:go-offline

COPY exam/src src

RUN mvn clean package

RUN mkdir logs

RUN useradd spring

RUN chown -R spring:spring /app

USER spring

EXPOSE 8080


CMD ["java","-jar","target/app.jar"]
