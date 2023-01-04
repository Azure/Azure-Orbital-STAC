FROM osgeo/gdal:ubuntu-small-3.5.1

RUN apt-get update
RUN apt-get install -y gdal-bin
RUN apt-get install -y python3.8
RUN apt-get install -y python3-pip

WORKDIR /app

COPY . /app

RUN pip install -e ./stac