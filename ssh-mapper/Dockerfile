FROM python:3.9

USER root

RUN useradd -m -u 1000 -s /bin/bash learner

WORKDIR /app

RUN chown -R learner:learner /app

COPY mapper/mapper.py .
COPY mapper/messages.py .
COPY manualparamiko ./manualparamiko/
COPY paramiko ./paramiko/
COPY dev-requirements.txt ./
COPY setup.py ./
COPY README.rst ./

RUN pip3 install -r dev-requirements.txt

ENV HOME=/home/learner

USER learner

ENTRYPOINT ["python3", "-u", "mapper.py"]
