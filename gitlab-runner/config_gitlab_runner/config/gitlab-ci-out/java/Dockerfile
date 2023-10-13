FROM openjdk:8
RUN  mkdir -p /app/logs
ENV JAVA_OPTS=""
ENV SPRING_PROFILES=""
WORKDIR /app
COPY  app.jar  app.jar
# plugins
# plugins for jmx
COPY jmx_exporter_config.yaml     jmx_exporter_config.yaml
COPY jmx_prometheus_javaagent.jar jmx_prometheus_javaagent.jar
# plugins for otel
COPY opentelemetry-javaagent.jar opentelemetry-javaagent.jar
ENV JAVA_TOOL_OPTIONS="-javaagent:opentelemetry-javaagent.jar"
ENV OTEL_SERVICE_NAME="template_sever_name"
ENV OTEL_TRACES_EXPORTER=jaeger
ENV OTEL_EXPORTER_JAEGER_ENDPOINT=http://jaeger-collector.tracing:14250
ENV OTEL_EXPORTER_JAEGER_TIMEOUT=10000
ENV OTEL_METRICS_EXPORTER="none"
# default env
ENV JAVA_OPTS="-Xms256m -Xmx512m"

CMD ["sh","-c","java -Djava.security.egd=file:/dev/./urandom -XX:ErrorFile=/data/servicesLog/logs/hs_err_pid_%p.log -server ${JAVA_OPTS} -XX:+UseG1GC -XX:-UseContainerSupport -javaagent:jmx_prometheus_javaagent.jar=12345:jmx_exporter_config.yaml -jar -XX:-OmitStackTraceInFastThrow /app/app.jar --spring.output.ansi.enabled=NEVER ${SPRING_PROFILES}"]