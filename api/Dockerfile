FROM ubuntu:latest
ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
MAINTAINER Cornel du Preez "cornel.dupreez@abrictosecurity.com"
RUN apt-get update -y
RUN apt-get install -y python3-pip python3-dev build-essential libmysqlclient-dev mysql-client zip awscli
RUN aws configure set default.region us-east-1
ADD . /flask
WORKDIR /flask
RUN pip3 install -r requirements.txt
RUN chmod +x report.sh
ENTRYPOINT ["python3"]
CMD ["app.py"]
