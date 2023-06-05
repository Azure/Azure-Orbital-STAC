FROM osgeo/gdal:ubuntu-small-3.5.1

RUN apt-get update -y \
 && apt-get install -y \
    gdal-bin \
    python3.8 \
    python3.8-venv \
    python3-pip

WORKDIR /app

RUN python3 -m venv /venv
ENV PATH="/venv/bin:$PATH"

COPY . .

RUN pip install --upgrade pip setuptools wheel \
 && pip install --no-cache-dir .
