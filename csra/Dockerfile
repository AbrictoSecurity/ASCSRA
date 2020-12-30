FROM node
MAINTAINER Cornel du Preez "cornel.dupreez@abrictosecurity.com"
RUN apt-get update -y && apt-get install -y \
    python3 \
    python3-pip \
    build-essential \
    git-core \
    curl \
    openssl \
    libssl-dev \
    awscli
ADD . /ASCSRA
WORKDIR /ASCSRA
RUN cd ./scans && \
    sed -i "s/\/\/ access_key/access_key/g" index.js && \
    sed -i "s/\/\/ secret_access_key/secret_access_key/g" index.js && \
    npm install && \
    cd ..
RUN pip3 install -r requirements.txt
ENTRYPOINT ["python3"]
CMD ["ASCSRA.py"]
