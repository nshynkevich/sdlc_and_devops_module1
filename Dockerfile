FROM openjdk:8-alpine

WORKDIR /

ADD VulnerableApp-1.0.0.jar VulnerableApp-1.0.0.jar

EXPOSE 9090

CMD java -jar VulnerableApp-1.0.0.jar
