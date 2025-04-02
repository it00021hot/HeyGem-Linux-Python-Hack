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
RUN wget --quiet https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -O ~/miniforge.sh && \
    bash ~/miniforge.sh -b -p /opt/conda && \
    rm ~/miniforge.sh && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo "source /opt/conda/etc/profile.d/conda.sh" >> /opt/nvidia/entrypoint.d/100.conda.sh && \
    echo "source /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate /code/HeyGem-Linux-Python-Hack/envs" >> /opt/nvidia/entrypoint.d/110.conda_default_env.sh && \
    echo "conda activate /code/HeyGem-Linux-Python-Hack/envs" >> $HOME/.bashrc

ENV PATH /opt/conda/bin:$PATH

RUN conda config --add channels conda-forge && \
    conda config --set channel_priority strict
# ------------------------------------------------------------------
# ~conda
# ==================================================================

RUN conda create -y --prefix /code/HeyGem-Linux-Python-Hack/envs python=3.8
ENV CONDA_DEFAULT_ENV=/code/HeyGem-Linux-Python-Hack/envs
ENV PATH /opt/conda/bin:/code/HeyGem-Linux-Python-Hack/envs/bin:$PATH

# 安装依赖
# 初始化 Conda
RUN conda init bash

# 激活 Conda 环境并安装依赖
RUN bash -c "source ~/.bashrc && \
             conda activate /code/HeyGem-Linux-Python-Hack/envs && \
             pip install --no-cache-dir -r requirements.txt"

# 下载模型
RUN bash download.sh


FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04 AS RUNNER

# 设置工作目录
WORKDIR /code

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    libsndfile1 \
    ffmpeg && \
    apt-get clean && \
    rm -r /var/lib/apt/lists/*

# 复制构建阶段HeyGem-Linux-Python-Hack目录下的所有文件到code下
COPY --from=BUILDER /code/HeyGem-Linux-Python-Hack/* /code

# 暴露端口
EXPOSE 8383

# 启动服务
CMD ["/code/envs/bin/python", "api_local.py"]  
