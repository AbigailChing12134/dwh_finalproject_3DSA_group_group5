# Start with the official Airflow image
FROM apache/airflow:2.7.1

# Switch to root to install system dependencies (needed for Java runtime)
USER root

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
         build-essential \
         curl \
         ca-certificates \
         openjdk-11-jre-headless \
         bash \
  && apt-get autoremove -yqq --purge \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Create directory for JDBC jars
RUN mkdir -p /opt/airflow/jars && chown -R airflow: /opt/airflow/jars

# Download Postgres JDBC driver
RUN curl -fSL -o /opt/airflow/jars/postgresql-42.6.0.jar \
    https://repo1.maven.org/maven2/org/postgresql/postgresql/42.6.0/postgresql-42.6.0.jar

# Switch back to airflow user to install Python packages
USER airflow

# Copy your requirements file into the container
COPY infra/etl/requirements.txt /requirements.txt

# Install the Python dependencies (includes pyspark from requirements.txt)
RUN pip install --no-cache-dir -r /requirements.txt

# Set Java environment variable required by Spark
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
# Ensure PATH includes the airflow user's local bin (where pip installs user packages) and standard system bins.
ENV PATH=/home/airflow/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
