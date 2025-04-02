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
RUN git clone https://github.com/it00021hot/HeyGem-Linux-Python-Hack.git && \
    cd HeyGem-Linux-Python-Hack

# 安装miniconda
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    bash Miniconda3-latest-Linux-x86_64.sh -b -p /miniconda && \
    rm Miniconda3-latest-Linux-x86_64.sh && \
    /miniconda/bin/conda init && \
    source /miniconda/bin/activate

ENV PATH="/miniconda/bin:$PATH"

# 创建虚拟环境
RUN /miniconda/bin/conda create --prefix /code/HeyGem-Linux-Python-Hack/envs python=3.8

# 激活虚拟环境/miniconda/envs/
RUN /miniconda/bin/conda activate /code/HeyGem-Linux-Python-Hack/envs

# 安装依赖

RUN pip install --no-cache-dir -r requirements.txt

# 下载模型
RUN bash download.sh


FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04 AS RUNNER

# 设置工作目录
WORKDIR /code

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    opencv-python-headless \
    libsndfile1 \
    ffmpeg

# 复制构建阶段HeyGem-Linux-Python-Hack目录下的所有文件到code下
COPY --from=BUILDER /code/HeyGem-Linux-Python-Hack/* /code

# 暴露端口
EXPOSE 8383

# 启动服务
CMD ["/code/envs/python", "api_local.py"]  
