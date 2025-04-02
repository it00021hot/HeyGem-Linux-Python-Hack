import os
import uuid
import time
import json
from flask import Flask, request, jsonify, send_file
from werkzeug.utils import secure_filename

import service.trans_dh_service
from h_utils.custom import CustomError
from y_utils.config import GlobalConfig
from y_utils.logger import logger

# 重用app.py中的视频写入函数替代
service.trans_dh_service.write_video = service.trans_dh_service.write_video

app = Flask(__name__)

class VideoProcessor:
    def __init__(self):
        self.task = service.trans_dh_service.TransDhTask()
        self.basedir = GlobalConfig.instance().result_dir
        self.is_initialized = False
        self._initialize_service()
        logger.info("VideoProcessor 初始化完成")

    def _initialize_service(self):
        logger.info("开始初始化 trans_dh_service...")
        try:
            time.sleep(5)
            logger.info("trans_dh_service 初始化完成。")
            self.is_initialized = True
        except Exception as e:
            logger.error(f"初始化 trans_dh_service 失败: {e}")

    def process_video(self, audio_file, video_file, watermark=False, digital_auth=False):
        while not self.is_initialized:
            logger.info("服务尚未完成初始化，等待 1 秒...")
            time.sleep(1)
        
        work_id = str(uuid.uuid1())
        code = work_id
        temp_dir = os.path.join(GlobalConfig.instance().temp_dir, work_id)
        result_dir = GlobalConfig.instance().result_dir

        try:
            audio_path = audio_file
            video_path = video_file

            self.task.task_dic[code] = ""
            self.task.work(audio_path, video_path, code, 0, 0, 0, 0)

            result_path = self.task.task_dic[code][2]
            final_result_dir = os.path.join("result", code)
            os.makedirs(final_result_dir, exist_ok=True)
            os.system(f"mv {result_path} {final_result_dir}")
            os.system(f"rm -rf {os.path.join(os.path.dirname(result_path), code + '*.*')}")
            result_path = os.path.realpath(os.path.join(final_result_dir, os.path.basename(result_path)))
            return result_path

        except Exception as e:
            logger.error(f"处理视频时发生错误: {e}")
            raise Exception(str(e))

# 初始化视频处理器
processor = VideoProcessor()

@app.route('/api/v1/process-video', methods=['POST'])
def process_video_api():
    """
    API接口用于处理视频和音频文件并生成数字人视频
    
    参数:
    - 通过multipart/form-data提交:
      - audio_file: 音频文件
      - video_file: 视频文件
      - watermark (可选): 是否添加水印 (1 或 0)
      - digital_auth (可选): 是否添加数字人标识 (1 或 0)
    
    返回:
    - JSON格式的处理结果
    """
    try:
        # 检查文件是否存在
        if 'audio_file' not in request.files or 'video_file' not in request.files:
            return jsonify({'status': 'error', 'message': '缺少音频或视频文件'}), 400
        
        audio_file = request.files['audio_file']
        video_file = request.files['video_file']
        
        # 检查文件名是否有效
        if audio_file.filename == '' or video_file.filename == '':
            return jsonify({'status': 'error', 'message': '未选择文件'}), 400
        
        # 安全地保存文件
        work_id = str(uuid.uuid1())
        temp_dir = os.path.join(GlobalConfig.instance().temp_dir, work_id)
        os.makedirs(temp_dir, exist_ok=True)
        
        audio_filename = secure_filename(audio_file.filename)
        video_filename = secure_filename(video_file.filename)
        
        audio_path = os.path.join(temp_dir, audio_filename)
        video_path = os.path.join(temp_dir, video_filename)
        
        audio_file.save(audio_path)
        video_file.save(video_path)
        
        # 获取可选参数
        watermark = request.form.get('watermark', '0') == '1'
        digital_auth = request.form.get('digital_auth', '0') == '1'
        
        # 处理视频
        result_path = processor.process_video(
            audio_path, 
            video_path, 
            watermark=watermark, 
            digital_auth=digital_auth
        )
        
        # 返回处理结果
        return jsonify({
            'status': 'success',
            'message': '视频处理成功',
            'result_path': result_path
        })
        
    except Exception as e:
        logger.error(f"API处理视频请求时发生错误: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/api/v1/video/<path:video_id>', methods=['GET'])
def get_video(video_id):
    """获取生成的视频文件"""
    try:
        video_path = os.path.join("result", video_id, f"{video_id}-r.mp4")
        if not os.path.exists(video_path):
            return jsonify({'status': 'error', 'message': '视频不存在'}), 404
        
        return send_file(video_path, mimetype='video/mp4')
    except Exception as e:
        logger.error(f"获取视频文件时发生错误: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/health', methods=['GET'])
def health_check():
    """健康检查接口"""
    return jsonify({'status': 'ok', 'service': 'digital-human-api'})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False) 