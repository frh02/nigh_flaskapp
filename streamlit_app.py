import streamlit as st
import os
import cv2

# Importing hypothetical modules for video processing - adapt these imports to your actual code
from rom_inference import video_rom
from sts_inference import video_sts
from tug_inference import video_tug

UPLOAD_FOLDER = 'temp_upload'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

def save_uploaded_file(uploaded_file):
    try:
        with open(os.path.join(UPLOAD_FOLDER, uploaded_file.name), "wb") as f:
            f.write(uploaded_file.getbuffer())
        return os.path.join(UPLOAD_FOLDER, uploaded_file.name)
    except Exception as e:
        st.error(f"Error saving file: {e}")
        return None

def video_processing(model_func, video_path):
    video_output = model_func(video_path)
    for frame_data in video_output:
        ret, buffer = cv2.imencode('.jpg', frame_data)
        if not ret:
            break
        frame_bytes = buffer.tobytes()
        yield frame_bytes

st.title("Video Analysis Platform")
uploaded_file = st.file_uploader("Upload a video file", type=['mp4', 'avi', 'mov'])

if uploaded_file is not None:
    saved_path = save_uploaded_file(uploaded_file)
    if saved_path:
        option = st.selectbox("Select the analysis model", ("ROM", "STS", "TUG"))

        if st.button("Analyze Video"):
            if option == 'ROM':
                model_function = video_rom
            elif option == 'STS':
                model_function = video_sts
            else:
                model_function = video_tug

            st.write("Processing video...")
            placeholder = st.empty()
            for frame_bytes in video_processing(model_function, saved_path):
                placeholder.image(frame_bytes, channels="BGR", use_column_width=True)