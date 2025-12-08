# Start with the official Airflow image
FROM apache/airflow:2.7.1

# Switch to root to install system dependencies (needed for some Python packages)
USER root
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
         build-essential \
  && apt-get autoremove -yqq --purge \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Switch back to the airflow user to install Python packages
USER airflow

# Copy your requirements file into the container
COPY infra/etl/requirements.txt /requirements.txt

# Install the Python dependencies
RUN pip install --no-cache-dir -r /requirements.txt