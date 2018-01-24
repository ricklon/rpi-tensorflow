FROM resin/rpi-raspbian:jessie  

RUN apt-get update && apt-get install -y --no-install-recommends \
 pkg-config wget zip g++ zlib1g-dev unzip \
 oracle-java8-jdk

RUN update-alternatives --config java

RUN apt-get install -y --no-install-recommends \
 python3-pip python3-numpy swig python3-dev

RUN pip3 install wheel

RUN apt-get install -y --no-install-recommends \  
 gcc-4.8 g++-4.8

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-4.8 100
RUN update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-4.8 100

RUN mkdir tensorflow
WORKDIR tensorflow

# Skipping Swap space
RUN wget https://github.com/bazelbuild/bazel/releases/download/0.5.4/bazel-0.5.4-dist.zip
RUN unzip -d bazel bazel-0.5.4-dist.zip
WORKDIR  bazel
#RUN echo "PWD is: $PWD"
RUN echo "$(ls ./scripts/bootstrap)"
RUN sed -i   '/.*-enc/ s/$/ -J-Xmx500M/'  ./scripts/bootstrap/compile.sh

RUN echo "$(ls)"
RUN ./compile.sh 2>&1 | tee buildLog.out
RUN cp output/bazel /usr/local/bin/bazel

# Tensorflow configuration
RUN  git clone --recurse-submodules https://github.com/tensorflow/tensorflow.git
WORKDIR tensorflow
RUN echo "PWD is: $PWD"

RUN git checkout v1.3.0
RUN grep -Rl 'lib64' | xargs sed -i 's/lib64/lib/g'
RUN sed -i   '/#define IS_MOBILE_PLATFORM/d' tensorflow/core/platform/platform.h
RUN sed -i  "s/f3a22f35b044/d781c1de9834/" tensorflow/workspace.bzl
RUN sed -i  "s/ca7beac153d4059c02c8fc59816c82d54ea47fe58365e8aded4082ded0b820c4/a34b208da6ec18fa8da963369e166e4a368612c14d956dd2f9d7072904675d9b/" tensorflow/workspace.bzl

RUN ./configure
RUN bazel build -c opt --copt="-mfpu=neon-vfpv4" \
   --copt="-funsafe-math-optimizations" \
   --copt="-ftree-vectorize" \
   --copt="-fomit-frame-pointer" \
   --local_resources 1024,1.0,1.0 \
   --verbose_failures tensorflow/tools/pip_package:build_pip_package \
   2>&1 | tee buildLog.out

RUN bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/tensorflow_pkg
RUN pip3 install /tmp/tensorflow_pkg/tensorflow-1.3.0-cp35-cp35m-linux_armv7l.whl
