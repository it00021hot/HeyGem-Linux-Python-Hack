FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04 AS BUILDER

# 设置工作目录
WORKDIR /code

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    wget \
    curl \
    ca-certificates

# 克隆项目
ADD . /code

# 安装miniconda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm -rf /tmp/miniconda.sh

ENV PATH /opt/conda/bin:$PATH

RUN conda update -n base -c defaults conda -y
RUN conda config --add channels conda-forge && \
    conda config --set channel_priority strict
# ------------------------------------------------------------------
# ~conda
# ==================================================================

# 创建 Conda 环境
RUN conda create -p /code/envs python=3.8 -y

# 安装依赖
RUN /code/envs/bin/pip install torch==2.1.2 torchvision==0.16.2 torchaudio==2.1.2 --index-url https://download.pytorch.org/whl/cu118 && \
    /code/envs/bin/pip install --no-cache-dir -r requirements.txt

# 下载模型
RUN bash download.sh


FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04 AS RUNNER

# 设置工作目录
WORKDIR /code

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    libsndfile1 \
    libgl1-mesa-glx \
    libglib2.0-0 \
    ffmpeg && \
    apt-get clean && \
    rm -r /var/lib/apt/lists/*

# 复制构建阶段HeyGem-Linux-Python-Hack目录下的所有文件到code下
COPY --from=BUILDER /code /code

# 暴露端口
EXPOSE 8383

# 启动服务
CMD ["/code/envs/bin/python", "api_local.py"]  
