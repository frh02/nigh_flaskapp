from flask import Flask, render_template, Response,jsonify,request,session, redirect, url_for

from flask_wtf import FlaskForm


from wtforms import FileField, SubmitField,StringField,DecimalRangeField,IntegerRangeField
from werkzeug.utils import secure_filename
from wtforms.validators import InputRequired,NumberRange
import os


# Required to run the YOLOv8 model
import cv2

# YOLO_Video is the python file which contains the code for our object detection model
#Video Detection is the Function which performs Object Detection on Input Video
from rom_inference import video_rom
from sts_inference import video_sts
from tug_inference import video_tug

app = Flask(__name__)

app.config['SECRET_KEY'] = 'farhan'
app.config['UPLOAD_FOLDER'] = 'static/files'
video_capture = None



#Use FlaskForm to get input video file  from user
class UploadFileForm(FlaskForm):
    #We store the uploaded video file path in the FileField in the variable file
    #We have added validators to make sure the user inputs the video in the valid format  and user does upload the
    #video when prompted to do so
    file = FileField("File",validators=[InputRequired()])
    submit = SubmitField("Run")


def generate_frames_video_rom(path_x = ''):
    yolo_output = video_rom(path_x)
    for detection_ in yolo_output:
        ref,buffer=cv2.imencode('.jpg',detection_)

        frame=buffer.tobytes()
        yield (b'--frame\r\n'
                    b'Content-Type: image/jpeg\r\n\r\n' + frame +b'\r\n')

def generate_frames_sts_video(path_x):
    yolo_output = video_sts(path_x)
    for detection_ in yolo_output:
        ref,buffer=cv2.imencode('.jpg',detection_)

        frame=buffer.tobytes()
        yield (b'--frame\r\n'
                    b'Content-Type: image/jpeg\r\n\r\n' + frame +b'\r\n')
        

def generate_frames_tug_video(path_x):
    yolo_output = video_tug(path_x)
    for detection_ in yolo_output:
        ref,buffer=cv2.imencode('.jpg',detection_)

        frame=buffer.tobytes()
        yield (b'--frame\r\n'
                    b'Content-Type: image/jpeg\r\n\r\n' + frame +b'\r\n')
        
def generate_frames_web_rom(path_x):
    global video_capture
    yolo_output = video_rom(path_x)
    for detection_ in yolo_output:
        ret, buffer = cv2.imencode('.jpg',detection_)
        if not ret:
            break
        frame= buffer.tobytes()
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')

def generate_frames_web_sts(path_x):
    global video_capture
    yolo_output = video_sts(path_x)
    for detection_ in yolo_output:
        ret, buffer = cv2.imencode('.jpg',detection_)
        if not ret:
            break
        frame= buffer.tobytes()
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')

def generate_frames_web_tug(path_x):
    global video_capture
    yolo_output = video_tug(path_x)
    for detection_ in yolo_output:
        ret, buffer = cv2.imencode('.jpg',detection_)
        if not ret:
            break
        frame= buffer.tobytes()
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')        

@app.route('/', methods=['GET','POST'])
@app.route('/home', methods=['GET','POST'])
def home():
    session.clear()
    return render_template('index.html')
# Rendering the Webcam Rage
@app.route('/stop_video', methods=['POST'])
def stop_video():
    global video_capture
    if video_capture is not None:
        video_capture.release()
        cv2.destroyAllWindows()
    # return redirect(url_for('webcam'))
    return render_template('transition.html')
#Now lets make a Webcam page for the application
#Use 'app.route()' method, to render the Webcam page at "/webcam"
@app.route("/rom/webcam", methods=['GET','POST'])
def rom_webcam():
    session.clear()
    return render_template('rom_web.html')

@app.route('/rom/video', methods=['GET','POST'])
def front():
    # Upload File Form: Create an instance for the Upload File Form
    form = UploadFileForm()
    if form.validate_on_submit():
        # Our uploaded video file path is saved here
        file = form.file.data
        file.save(os.path.join(os.path.abspath(os.path.dirname(__file__)), app.config['UPLOAD_FOLDER'],
                               secure_filename(file.filename)))  # Then save the file
        # Use session storage to save video file path
        session['video_path'] = os.path.join(os.path.abspath(os.path.dirname(__file__)), app.config['UPLOAD_FOLDER'],
                                             secure_filename(file.filename))
    return render_template('rom_video.html', form=form)

@app.route("/sts/webcam", methods=['GET','POST'])
def sts_webcam():
    session.clear()
    return render_template('sts_web.html')

@app.route('/sts/video', methods=['GET','POST'])
def front_sts():
    # Upload File Form: Create an instance for the Upload File Form
    form = UploadFileForm()
    if form.validate_on_submit():
        # Our uploaded video file path is saved here
        file = form.file.data
        file.save(os.path.join(os.path.abspath(os.path.dirname(__file__)), app.config['UPLOAD_FOLDER'],
                               secure_filename(file.filename)))  # Then save the file
        # Use session storage to save video file path
        session['video_path'] = os.path.join(os.path.abspath(os.path.dirname(__file__)), app.config['UPLOAD_FOLDER'],
                                             secure_filename(file.filename))
        
        print("This is the vid",session['video_path'])
    return render_template('sts_video.html', form=form)


@app.route("/tug/webcam", methods=['GET','POST'])
def tug_webcam():
    session.clear()
    return render_template('tug_web.html')

@app.route('/tug/video', methods=['GET','POST'])
def front_tug():
    # Upload File Form: Create an instance for the Upload File Form
    form = UploadFileForm()
    if form.validate_on_submit():
        # Our uploaded video file path is saved here
        file = form.file.data
        file.save(os.path.join(os.path.abspath(os.path.dirname(__file__)), app.config['UPLOAD_FOLDER'],
                               secure_filename(file.filename)))  # Then save the file
        # Use session storage to save video file path
        session['video_path'] = os.path.join(os.path.abspath(os.path.dirname(__file__)), app.config['UPLOAD_FOLDER'],
                                             secure_filename(file.filename))
        
        print("This is the vid",session['video_path'])
    return render_template('tug_video.html', form=form)

@app.route('/sts')
def sts():
    return render_template('sts.html')

@app.route('/rom')
def rom():
    return render_template('rom.html')

@app.route('/tug')
def tug():
    return render_template('tug.html')

# To display the Output Video on Webcam page
@app.route('/video')
def video_for_rom():
    #return Response(generate_frames(path_x='static/files/bikes.mp4'), mimetype='multipart/x-mixed-replace; boundary=frame')
    return Response(generate_frames_video_rom(path_x = session.get('video_path', None)),mimetype='multipart/x-mixed-replace; boundary=frame')

# To display the Output Video on Webcam page
@app.route('/webapp')
def webapp_rom():
    #return Response(generate_frames(path_x = session.get('video_path', None),conf_=round(float(session.get('conf_', None))/100,2)),mimetype='multipart/x-mixed-replace; boundary=frame')
    return Response(generate_frames_web_rom(path_x=1), mimetype='multipart/x-mixed-replace; boundary=frame')


@app.route('/video/sts')
def video_for_sts():
    #return Response(generate_frames(path_x='static/files/bikes.mp4'), mimetype='multipart/x-mixed-replace; boundary=frame')
    return Response(generate_frames_sts_video(path_x = session.get('video_path', None)),mimetype='multipart/x-mixed-replace; boundary=frame')

# To display the Output Video on Webcam page
@app.route('/webapp/sts')
def webapp_sts():
    #return Response(generate_frames(path_x = session.get('video_path', None),conf_=round(float(session.get('conf_', None))/100,2)),mimetype='multipart/x-mixed-replace; boundary=frame')
    return Response(generate_frames_web_sts(path_x=1), mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/video/tug')
def video_for_tug():
    #return Response(generate_frames(path_x='static/files/bikes.mp4'), mimetype='multipart/x-mixed-replace; boundary=frame')
    return Response(generate_frames_tug_video(path_x = session.get('video_path', None)),mimetype='multipart/x-mixed-replace; boundary=frame')

# To display the Output Video on Webcam page
@app.route('/webapp/tug')
def webapp_tug():
    #return Response(generate_frames(path_x = session.get('video_path', None),conf_=round(float(session.get('conf_', None))/100,2)),mimetype='multipart/x-mixed-replace; boundary=frame')
    return Response(generate_frames_web_tug(path_x=1), mimetype='multipart/x-mixed-replace; boundary=frame')

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5001)