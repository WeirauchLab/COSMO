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
RUN apt-get install -y --no-install-recommends make less vim-tiny

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

# the rest of these are all things that `make install` would do for you,
# *outside* the container
WORKDIR /usr/src
RUN git clone https://github.com/jhkorhonen/MOODS.git
WORKDIR MOODS
RUN git checkout de2a2a8
WORKDIR src
RUN make -j8
WORKDIR ../python
RUN python setup.py install

WORKDIR /usr/src
COPY README.md requirements.txt Makefile setup.py cosmo.py cosmostats.py ./
RUN python setup.py install

WORKDIR /usr/local/bin
RUN ln -s cosmo.py cosmo
RUN ln -s cosmostats.py cosmostats

RUN rm -r /usr/src
RUN apt-get remove -y $BUILD_PACKAGES && \
    apt-get autoremove -y && \
    apt-get clean -y

COPY examples/jpwm /usr/local/cosmo/jpwm

# this will probably match the local user, 1000:1000, avoiding problems with
# files created by root within the container
RUN useradd -m cosmo
USER cosmo
RUN echo 'export COSMO_PWMDIR=/usr/local/lib/cosmo/jpwm' >> ~/.bashrc

WORKDIR /src
