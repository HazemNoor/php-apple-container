FROM phpmyadmin:latest

RUN apt-get update && apt-get install -y curl unzip && \
    curl -o /tmp/boodark-1.1.0.zip https://files.phpmyadmin.net/themes/boodark/1.1.0/boodark-1.1.0.zip && \
    unzip /tmp/boodark-1.1.0.zip -d /var/www/html/themes && \
    rm /tmp/boodark-1.1.0.zip && \
    apt-get purge -y curl unzip && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
