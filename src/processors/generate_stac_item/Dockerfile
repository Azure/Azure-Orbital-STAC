FROM osgeo/gdal:ubuntu-small-3.5.1

RUN apt-get update
RUN apt-get install -y gdal-bin
RUN apt-get install -y python3.8
RUN apt-get install -y python3-pip

WORKDIR /app

COPY ./requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir --upgrade -r /app/requirements.txt
COPY . /app
CMD ["python3", "/app/main.py"]