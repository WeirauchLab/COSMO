FROM debian:stable-slim
SHELL ["/bin/bash", "-c"]
ARG PYVER=2.7.18
# probably doubles the build time, but if you want it set to '1'
ARG PYOPTIMIZED=
ENV DEBIAN_FRONTEND=noninteractive
ENV BUILD_PACKAGES="build-essential wget git ca-certificates zlib1g-dev libssl-dev"

RUN apt-get update
RUN apt-get install -y --no-install-recommends $BUILD_PACKAGES
# mark as "manually installed" so it isn't autoremoved later
RUN apt-get install -y --no-install-recommends make

WORKDIR /usr/src
RUN wget --no-verbose https://www.python.org/ftp/python/$PYVER/Python-$PYVER.tgz
# source: https://www.python.org/downloads/release/python-2718
RUN md5sum -c <(echo "38c84292658ed4456157195f1c9bcbe1  Python-$PYVER.tgz")
RUN tar xzf Python*

WORKDIR Python-$PYVER
# `--enable-optimizations` here runs a lot of tests, and we don't really care
# h/t: https://stackoverflow.com/a/44800991
RUN ./configure $( (( PYOPTIMIZED)) && echo --enable-optimizations )
RUN make -j8 && make install

# source: https://pip.pypa.io/en/stable/installation (more or less)
RUN wget --no-verbose https://bootstrap.pypa.io/pip/2.7/get-pip.py
RUN python get-pip.py

RUN git clone https://github.com/jhkorhonen/MOODS.git
WORKDIR MOODS
RUN git checkout de2a2a8
WORKDIR src
RUN make -j8
WORKDIR ../python
RUN python setup.py install

COPY requirements.txt .
RUN pip install -r requirements.txt

RUN rm -r /usr/src
RUN apt-get remove -y $BUILD_PACKAGES && \
    apt-get autoremove -y && \
    apt-get clean -y

WORKDIR /src
CMD ["make"]
